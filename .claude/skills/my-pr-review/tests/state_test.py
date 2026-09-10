#!/usr/bin/env python3
"""state.py の単体テスト。実行: python3 tests/state_test.py"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
import state  # noqa: E402

FIXTURES = os.path.join(HERE, "fixtures")
STATE_PY = os.path.join(HERE, "..", "scripts", "state.py")


def run(args, stdin=None):
    p = subprocess.run([sys.executable, STATE_PY, *args], input=stdin, capture_output=True, text=True)
    if p.returncode != 0:
        raise AssertionError(f"state.py {' '.join(args)} failed: {p.stderr}")
    return json.loads(p.stdout) if p.stdout.strip() else None


class NormalizeTest(unittest.TestCase):
    def test_normalize_collapses_whitespace(self):
        self.assertEqual(state.normalize_snippet("\tif  user.NewFlag {  \n\t\treturn nil"), "if user.NewFlag {\nreturn nil")

    def test_fingerprint_is_stable_under_whitespace(self):
        a = state.fingerprint_of("観点1", "既存ユーザーで  false になる")
        b = state.fingerprint_of("観点1", " 既存ユーザーで false になる ")
        self.assertEqual(a, b)


class ScopeTest(unittest.TestCase):
    def setUp(self):
        with open(os.path.join(FIXTURES, "offset.go"), encoding="utf-8") as f:
            self.lines = f.read().split("\n")

    def test_inside_function(self):
        self.assertEqual(state.extract_scope(self.lines, 14, "offset.go"), "func (s *Service) Offset(ctx context.Context, in Input) error")

    def test_top_level_is_null(self):
        self.assertIsNone(state.extract_scope(self.lines, 9, "offset.go"))

    def test_inside_type_is_null(self):
        self.assertIsNone(state.extract_scope(self.lines, 6, "offset.go"))

    def test_non_go_is_null(self):
        self.assertIsNone(state.extract_scope(["  x = 1"], 1, "a.py"))


class EnrichTest(unittest.TestCase):
    def test_enrich_reads_snippet_and_scope(self):
        out = run(["enrich", "--worktree", FIXTURES], json.dumps({"findings": [{"file": "offset.go", "line": {"start": 14, "end": 16}, "perspective": "観点5", "summary": "s", "body": "b"}]}))
        f = out["findings"][0]
        self.assertEqual(f["snippet"], "\tif user.NewFlag {\n\t\treturn nil\n\t}")
        self.assertEqual(f["scope"], "func (s *Service) Offset(ctx context.Context, in Input) error")
        self.assertEqual(f["snippet_sha256"], state.sha256("if user.NewFlag {\nreturn nil\n}"))

    def test_missing_file_gives_null_snippet(self):
        out = run(["enrich", "--worktree", FIXTURES], json.dumps({"findings": [{"file": "nope.go", "line": 1, "perspective": None, "summary": "s", "body": "b"}]}))
        self.assertIsNone(out["findings"][0]["snippet"])
        self.assertIsNone(out["findings"][0]["snippet_sha256"])


class MatchTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state_file = os.path.join(self.tmp.name, "threads.jsonl")
        self.prior = state.new_record(
            key="k1", file="offset.go", scope="func (s *Service) Offset(ctx context.Context, in Input) error",
            snippet="\tif user.NewFlag {", snippet_sha256=state.sha256("if user.NewFlag {"),
            perspective="観点5", summary="旧要約", reason="バックフィル済み", fingerprint=state.fingerprint_of("観点5", "旧要約"),
            origin="claude", difit_thread_id="claude-1", status="dismissed",
        )
        state.append_records(self.state_file, [self.prior])

    def tearDown(self):
        self.tmp.cleanup()

    def finding(self, **kw):
        base = {"file": "offset.go", "line": 14, "perspective": "観点5", "summary": "新要約", "body": "b"}
        base.update(kw)
        return base

    def enrich_and_match(self, finding):
        enriched = run(["enrich", "--worktree", FIXTURES], json.dumps({"findings": [finding]}))
        return run(["match", "--state", self.state_file], json.dumps(enriched))["findings"][0]

    def test_same_snippet_same_perspective_is_suppressed(self):
        f = self.enrich_and_match(self.finding())
        self.assertEqual(f["decision"], "suppress")
        self.assertEqual(f["prior"]["reason"], "バックフィル済み")

    def test_same_snippet_other_perspective_is_annotated(self):
        f = self.enrich_and_match(self.finding(perspective="観点1"))
        self.assertEqual(f["decision"], "annotate")

    def test_changed_snippet_same_scope_and_fingerprint_is_annotated(self):
        f = self.enrich_and_match(self.finding(line=15, summary="旧要約"))
        self.assertEqual(f["decision"], "annotate")

    def test_changed_snippet_different_summary_is_reported(self):
        f = self.enrich_and_match(self.finding(line=15))
        self.assertEqual(f["decision"], "report")

    def test_latest_record_wins(self):
        state.append_records(self.state_file, [dict(self.prior, status="open", perspective="観点9")])
        f = self.enrich_and_match(self.finding())
        self.assertEqual(f["decision"], "annotate")

    def test_to_difit_skips_suppressed_and_prepends_annotation(self):
        decided = {"findings": [
            dict(self.finding(), decision="suppress", fingerprint="x", prior=self.prior),
            dict(self.finding(perspective="観点1"), decision="annotate", fingerprint="y", prior=self.prior),
            dict(self.finding(line=20), decision="report", fingerprint="z", prior=None),
        ]}
        out = run(["to-difit", "--repo", "o/r", "--pr", "1", "--head-sha", "abc"], json.dumps(decided))
        self.assertEqual(len(out["imports"]), 2)
        self.assertTrue(out["imports"][0]["body"].startswith("> 過去の判断: 対応不要と判断済み"))
        self.assertIn("> 理由: バックフィル済み", out["imports"][0]["body"])
        self.assertEqual(out["imports"][0]["author"], "claude")
        self.assertEqual(out["records"][1]["key"], "z")
        self.assertEqual(out["records"][1]["difit_thread_id"], out["imports"][1]["id"])


class StatusTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state_file = os.path.join(self.tmp.name, "threads.jsonl")
        run(["append", "--state", self.state_file], json.dumps([state.new_record(key="k", origin="claude", difit_thread_id="d1", status="open", summary="s")]))

    def tearDown(self):
        self.tmp.cleanup()

    def test_set_status_appends_and_latest_reflects(self):
        run(["set-status", "--state", self.state_file, "--difit-id", "d1", "--status", "dismissed", "--reason", "r"])
        with open(self.state_file, encoding="utf-8") as f:
            self.assertEqual(len(f.read().strip().splitlines()), 2)
        latest = run(["latest", "--state", self.state_file, "--status", "dismissed"])
        self.assertEqual(latest[0]["reason"], "r")
        self.assertEqual(run(["latest", "--state", self.state_file, "--status", "open"]), [])

    def test_append_rejects_invalid_status(self):
        p = subprocess.run([sys.executable, STATE_PY, "append", "--state", self.state_file], input=json.dumps([{"key": "x", "status": "bogus"}]), capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)


class GithubTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state_file = os.path.join(self.tmp.name, "threads.jsonl")
        with open(os.path.join(FIXTURES, "github-threads.json"), encoding="utf-8") as f:
            self.payload = f.read()

    def tearDown(self):
        self.tmp.cleanup()

    def test_from_github_positions_and_records(self):
        out = run(["from-github", "--state", self.state_file, "--repo", "o/r", "--pr", "1", "--head-sha", "abc", "--worktree", FIXTURES], self.payload)
        ids = [i["id"] for i in out["imports"]]
        self.assertEqual(ids, ["PRRC_open_root", "PRRC_open_reply", "PRRC_left_root"])
        self.assertEqual(out["imports"][1]["type"], "reply")
        self.assertEqual(out["imports"][2]["position"], {"side": "old", "line": 5})
        by_key = {r["key"]: r for r in out["records"]}
        self.assertEqual(by_key["PRRT_open"]["status"], "open")
        self.assertEqual(by_key["PRRT_open"]["snippet"], "\tif user.NewFlag {")
        self.assertEqual(by_key["PRRT_resolved"]["status"], "resolved")
        self.assertEqual(by_key["PRRT_resolved"]["line"], {"start": 11, "end": 12})
        self.assertNotIn("PRRT_outdated", by_key)

    def test_from_github_updates_difit_id_of_known_thread(self):
        prior = state.new_record(key="fp", origin="claude", difit_thread_id="claude-1", github_thread_id="PRRT_open", status="posted", summary="s", file="offset.go")
        state.append_records(self.state_file, [prior])
        out = run(["from-github", "--state", self.state_file, "--repo", "o/r", "--pr", "1", "--head-sha", "abc"], self.payload)
        updated = [r for r in out["records"] if r["key"] == "fp"]
        self.assertEqual(updated[0]["difit_thread_id"], "PRRC_open_root")
        self.assertEqual(updated[0]["status"], "posted")

    def test_reconcile(self):
        recs = [
            state.new_record(key="a", origin="claude", github_thread_id="PRRT_open", status="posted", summary="s"),
            state.new_record(key="b", origin="claude", github_thread_id="PRRT_resolved", status="posted", summary="s"),
            state.new_record(key="c", origin="claude", github_thread_id="PRRT_gone", status="posted", summary="s"),
        ]
        state.append_records(self.state_file, recs)
        out = run(["reconcile", "--state", self.state_file], self.payload)
        by_key = {r["key"]: r["status"] for r in out["records"]}
        self.assertEqual(by_key, {"b": "resolved", "c": "dismissed"})

    def test_reconcile_holds_when_pending_review_exists(self):
        state.append_records(self.state_file, [state.new_record(key="c", origin="claude", github_thread_id="PRRT_gone", status="posted", summary="s")])
        payload = json.loads(self.payload)
        payload["viewer_pending_review_id"] = "PRR_1"
        out = run(["reconcile", "--state", self.state_file], json.dumps(payload))
        self.assertEqual(out["records"], [])
        self.assertEqual(len(out["warnings"]), 1)


class ShorthandTest(unittest.TestCase):
    def test_plus_and_minus_alone(self):
        self.assertEqual(state.classify_reply("+"), ("fix", ""))
        self.assertEqual(state.classify_reply(" - \n"), ("dismiss", ""))
        self.assertEqual(state.classify_reply("＋"), ("fix", ""))

    def test_plus_and_minus_take_following_text(self):
        # "+" / "-" は "対応" / "不要" と同じ先頭一致で、続く本文を補足または理由として扱う。
        # 箇条書きの "- 項目" や "+1" を対応要否と読むことになるが、実運用で困らないため許容する。
        self.assertEqual(state.classify_reply("+ 明細ごとの切り捨ては問題ありません"), ("fix", "明細ごとの切り捨ては問題ありません"))
        self.assertEqual(state.classify_reply("+\n明細ごとの切り捨ては問題ありません"), ("fix", "明細ごとの切り捨ては問題ありません"))
        self.assertEqual(state.classify_reply("- マイグレーションで対応済み"), ("dismiss", "マイグレーションで対応済み"))
        self.assertEqual(state.classify_reply("- 項目1\n- 項目2"), ("dismiss", "項目1\n- 項目2"))
        self.assertEqual(state.classify_reply("+1 です"), ("fix", "1 です"))


class ToClaudePrefixTest(unittest.TestCase):
    def test_q_with_separator_is_to_claude(self):
        self.assertEqual(state.classify_reply("q この記述は正しいですか？"), ("to_claude", "この記述は正しいですか？"))
        self.assertEqual(state.classify_reply("Q: なぜ？"), ("to_claude", "なぜ？"))
        self.assertEqual(state.classify_reply("q\nなぜ？"), ("to_claude", "なぜ？"))
        self.assertEqual(state.classify_reply("q　全角空白でも"), ("to_claude", "全角空白でも"))
        self.assertEqual(state.classify_reply("q この指摘は取り下げて"), ("to_claude", "この指摘は取り下げて"))

    def test_q_without_separator_is_not_to_claude(self):
        self.assertEqual(state.classify_reply("query が空のときは？")[0], "other")
        self.assertEqual(state.classify_reply("q")[0], "other")

    def test_other_prefixes_are_reviewee_comments(self):
        for body in ("質問: この関数は分けるべき？", "@claude これは？", "? ここは意図的ですか", "？ なぜ"):
            self.assertEqual(state.classify_reply(body), ("other", body))

    def test_prefix_needs_separator(self):
        self.assertEqual(state.classify_reply("不要な変数が残っている"), ("other", "不要な変数が残っている"))
        self.assertEqual(state.classify_reply("対応した方が良さそう。"), ("other", "対応した方が良さそう。"))
        self.assertEqual(state.classify_reply("不要"), ("dismiss", ""))
        self.assertEqual(state.classify_reply("対応 ただしログは warn で"), ("fix", "ただしログは warn で"))


class TriageTest(unittest.TestCase):
    def test_classification(self):
        with open(os.path.join(FIXTURES, "difit-comments.json"), encoding="utf-8") as f:
            payload = f.read()
        with tempfile.TemporaryDirectory() as d:
            out = run(["triage", "--state", os.path.join(d, "threads.jsonl")], payload)
        got = {t["difit_thread_id"]: (t["classification"], t["text"]) for t in out["threads"]}
        self.assertEqual(got["claude-fix"], ("fix", "ただしログは warn で"))
        self.assertEqual(got["claude-dismiss"], ("dismiss", "バックフィル済み"))
        self.assertEqual(got["claude-to-claude"], ("to_claude", "他の方法は？"))
        self.assertEqual(got["claude-answered"][0], "none")
        self.assertEqual(got["claude-pending"][0], "pending")
        # q も + も - も付かない返信はレビュイーへのコメントなので fix になる
        self.assertEqual(got["claude-reviewee-comment"], ("fix", "ここは仕様の変更が必要では？"))
        self.assertEqual(got["user-to-claude"], ("to_claude", "ここは分けるべき？"))
        self.assertEqual(got["claude-to-claude-after-plus"], ("to_claude", "この記述は正しいですか？"))
        self.assertEqual(got["user-finding"][0], "user_finding")
        self.assertEqual(got["user-finding-dismissed"], ("dismiss", "やっぱり良い"))
        self.assertEqual(got["PRRC_open_root"][0], "github")


class RegisterTest(unittest.TestCase):
    def test_register_only_unknown_threads(self):
        with open(os.path.join(FIXTURES, "difit-comments.json"), encoding="utf-8") as f:
            payload = f.read()
        with tempfile.TemporaryDirectory() as d:
            state_file = os.path.join(d, "threads.jsonl")
            state.append_records(state_file, [state.new_record(key="fp", origin="claude", difit_thread_id="claude-fix", status="open", summary="s")])
            out = run(["register", "--state", state_file, "--repo", "o/r", "--pr", "1", "--head-sha", "h", "--worktree", FIXTURES], payload)
        recs = {r["key"]: r for r in out["records"]}
        self.assertNotIn("claude-fix", recs)
        self.assertEqual(recs["user-finding"]["origin"], "user")
        self.assertEqual(recs["user-finding"]["snippet"], "\tif err != nil {")
        self.assertEqual(recs["claude-dismiss"]["origin"], "claude")


class GithubBodyTest(unittest.TestCase):
    claude_root = {"body": "> 過去の判断: 既出\n> 理由: x\n\n#1 [重要度] 中🟡\n\n[修正案]\n\n寄せてください。", "author": "claude"}

    def test_reply_then_separator_then_finding_without_annotation(self):
        body = state.github_body(self.claude_root, [{"body": "対応した方が良さそう。", "author": None}])
        self.assertEqual(body, "対応した方が良さそう。\n\n---\n\n#1 [重要度] 中🟡\n\n[修正案]\n\n寄せてください。")

    def test_bare_directive_is_omitted(self):
        body = state.github_body(self.claude_root, [{"body": "+", "author": None}])
        self.assertEqual(body, "#1 [重要度] 中🟡\n\n[修正案]\n\n寄せてください。")
        body = state.github_body(self.claude_root, [{"body": "対応", "author": None}])
        self.assertFalse(body.startswith("対応"))

    def test_claude_replies_and_q_are_not_included(self):
        body = state.github_body(self.claude_root, [{"body": "q なぜ？", "author": None}, {"body": "回答です", "author": "claude"}, {"body": "ではそれで", "author": None}])
        self.assertTrue(body.startswith("ではそれで\n\n---"))
        self.assertNotIn("回答です", body)
        self.assertNotIn("なぜ？", body)

    def test_q_reply_is_not_included(self):
        body = state.github_body(self.claude_root, [{"body": "q この記述は正しいですか？", "author": None}, {"body": "回答です", "author": "claude"}, {"body": "+", "author": None}])
        self.assertEqual(body, "#1 [重要度] 中🟡\n\n[修正案]\n\n寄せてください。")

    def test_reviewee_comment_is_included(self):
        body = state.github_body(self.claude_root, [{"body": "ここは仕様の変更が必要では？", "author": None}])
        self.assertTrue(body.startswith("ここは仕様の変更が必要では？\n\n---"))

    def test_user_thread_starting_with_q_has_no_body(self):
        self.assertEqual(state.github_body({"body": "q ここは分けるべき？", "author": None}, []), "")
        self.assertEqual(state.github_body({"body": "q ここは分けるべき？", "author": None}, [{"body": "+", "author": None}]), "")

    def test_github_thread_is_kept_as_is(self):
        self.assertEqual(state.github_body({"body": "質問: なぜ？", "author": "alice"}, []), "質問: なぜ？")

    def test_user_thread_is_posted_as_is(self):
        body = state.github_body({"body": "err をラップして", "author": None}, [{"body": "ここも同様", "author": None}])
        self.assertEqual(body, "err をラップして")

    def test_triage_output_has_github_body(self):
        with open(os.path.join(FIXTURES, "difit-comments.json"), encoding="utf-8") as f:
            payload = f.read()
        with tempfile.TemporaryDirectory() as d:
            out = run(["triage", "--state", os.path.join(d, "threads.jsonl")], payload)
        got = {t["difit_thread_id"]: t["github_body"] for t in out["threads"]}
        # レビュイーは対応要否の表明そのものを読む必要がないため、先頭語を落とした本文を載せる。
        self.assertEqual(got["claude-fix"], "ただしログは warn で\n\n---\n\n指摘A")
        self.assertEqual(got["user-finding"], "err をラップして")


class RelocateTest(unittest.TestCase):
    def test_relocate_finds_unique_snippet(self):
        rec = state.new_record(key="k", file="offset.go", side="new", line=99, snippet="  if user.NewFlag {\n return nil", status="open", summary="s")
        out = run(["relocate", "--worktree", FIXTURES], json.dumps([rec]))
        self.assertTrue(out["records"][0]["relocated"])
        self.assertEqual(out["records"][0]["line"], {"start": 14, "end": 15})

    def test_relocate_fails_on_ambiguous_or_missing(self):
        rec = state.new_record(key="k", file="offset.go", side="new", line=1, snippet="}", status="open", summary="s")
        out = run(["relocate", "--worktree", FIXTURES], json.dumps([rec]))
        self.assertFalse(out["records"][0]["relocated"])


class RebuildTest(unittest.TestCase):
    def test_rebuild_records_user_threads_and_replays_replies(self):
        with tempfile.TemporaryDirectory() as d:
            state_file = os.path.join(d, "threads.jsonl")
            snapshot = os.path.join(d, "difit-last.json")
            claude = state.new_record(key="fp", file="offset.go", side="new", line=99, snippet="\tif user.NewFlag {", body="指摘", origin="claude", difit_thread_id="claude-1", status="open", summary="s")
            posted = state.new_record(key="fp2", file="offset.go", side="new", line=10, snippet="\tif err != nil {", body="投稿済み", origin="claude", difit_thread_id="claude-2", github_thread_id="PRRT_x", status="posted", summary="s")
            state.append_records(state_file, [claude, posted])
            with open(snapshot, "w", encoding="utf-8") as f:
                json.dump({"threads": [
                    {"id": "claude-1", "filePath": "offset.go", "position": {"side": "new", "line": 99},
                     "messages": [{"id": "m1", "body": "指摘", "author": "claude"}, {"id": "m2", "body": "q なぜ？", "author": None}]},
                    {"id": "user-1", "filePath": "offset.go", "position": {"side": "new", "line": 17},
                     "messages": [{"id": "u1", "body": "ここは分ける", "author": None}]},
                    {"id": "user-gone", "filePath": "offset.go", "position": {"side": "new", "line": 3},
                     "messages": [{"id": "u2", "body": "消える行", "author": None}]},
                ]}, f)
            with open(os.path.join(FIXTURES, "offset.go"), encoding="utf-8") as f:
                src = f.read()
            wt = os.path.join(d, "wt"); os.makedirs(wt)
            subprocess.run(["git", "init", "-q", wt], check=True)
            with open(os.path.join(wt, "offset.go"), "w", encoding="utf-8") as f:
                f.write(src)
            subprocess.run(["git", "-C", wt, "-c", "user.name=t", "-c", "user.email=t@example.com", "add", "."], check=True)
            subprocess.run(["git", "-C", wt, "-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-qm", "old"], check=True)
            old_sha = subprocess.run(["git", "-C", wt, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
            with open(os.path.join(wt, "offset.go"), "w", encoding="utf-8") as f:
                f.write(src.replace('import "context"', "// removed"))
            out = run(["rebuild", "--state", state_file, "--repo", "o/r", "--pr", "1", "--head-sha", "new", "--worktree", wt, "--snapshot", snapshot, "--snapshot-head-sha", old_sha])
        kinds = [(i["type"], i["id"]) for i in out["imports"]]
        self.assertIn(("thread", "claude-1"), kinds)
        self.assertIn(("reply", "m2"), kinds)
        self.assertIn(("thread", "user-1"), kinds)
        self.assertNotIn(("thread", "claude-2"), kinds)
        by_id = {i["id"]: i for i in out["imports"]}
        self.assertNotIn("author", by_id["user-1"])
        self.assertNotIn("author", by_id["m2"])
        self.assertEqual(by_id["claude-1"]["position"]["line"], 14)
        self.assertEqual(by_id["m2"]["position"]["line"], 14)
        self.assertEqual(by_id["user-1"]["position"]["line"], 17)
        recs = {r["key"]: r for r in out["records"]}
        self.assertEqual(recs["user-1"]["origin"], "user")
        self.assertEqual(recs["user-1"]["snippet"], "\treturn s.repo.Save(ctx, user)")
        self.assertEqual(recs["user-gone"]["status"], "outdated")
        self.assertEqual(recs["fp"]["line"], 14)
        self.assertEqual(recs["fp"]["head_sha"], "new")
        self.assertEqual([o["key"] for o in out["outdated"]], ["user-gone"])


if __name__ == "__main__":
    unittest.main(verbosity=1)

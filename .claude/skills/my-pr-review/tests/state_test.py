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
        self.assertEqual(out["records"][1]["key"], out["imports"][1]["id"])
        self.assertEqual(out["records"][1]["difit_thread_id"], out["imports"][1]["id"])
        self.assertEqual(out["records"][1]["fingerprint"], "z")

    def test_findings_with_the_same_fingerprint_keep_separate_records(self):
        # 観点と要約が同じでも、別の箇所への指摘は別のレコードとして残す (key を fingerprint にすると 1 件にまとまる)
        decided = {"findings": [
            dict(self.finding(file="a_test.go"), decision="report", fingerprint="same", prior=None),
            dict(self.finding(file="b_test.go"), decision="report", fingerprint="same", prior=None),
        ]}
        out = run(["to-difit", "--repo", "o/r", "--pr", "1", "--head-sha", "abc"], json.dumps(decided))
        run(["append", "--state", self.state_file], json.dumps(out["records"]))
        keys = [r["key"] for r in out["records"]]
        self.assertEqual(len(set(keys)), 2)
        self.assertEqual(keys, [i["id"] for i in out["imports"]])
        latest = run(["latest", "--state", self.state_file])
        self.assertEqual(sorted(r["file"] for r in latest if r["fingerprint"] == "same"), ["a_test.go", "b_test.go"])


class DirectiveTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state_file = os.path.join(self.tmp.name, "threads.jsonl")
        self.fixed = state.new_record(
            key="d1", file="offset.go", perspective="観点5", summary="兄弟と形が違う", body="b",
            fingerprint="d1", origin="claude", difit_thread_id="claude-d1", status="open",
        )
        self.dismissed = state.new_record(key="d2", file="offset.go", summary="不要", origin="claude", difit_thread_id="claude-d2", status="open")
        state.append_records(self.state_file, [self.fixed, self.dismissed])
        run(["set-status", "--state", self.state_file, "--difit-id", "claude-d1", "--status", "resolved",
             "--reason", "abc1234", "--instruction", "兄弟と揃えて", "--fix-commit", "abc1234"])
        run(["set-status", "--state", self.state_file, "--difit-id", "claude-d2", "--status", "dismissed", "--reason", "理由"])

    def tearDown(self):
        self.tmp.cleanup()

    def finding(self, **kw):
        base = {"file": "offset.go", "line": 14, "perspective": "観点7", "summary": "元の形へ戻すべき", "body": "b"}
        base.update(kw)
        return base

    def match(self, finding):
        enriched = run(["enrich", "--worktree", FIXTURES], json.dumps({"findings": [finding]}))
        return run(["match", "--state", self.state_file], json.dumps(enriched))

    def test_directives_lists_only_resolved_records_with_fix_commit(self):
        rows = run(["directives", "--state", self.state_file])
        self.assertEqual([r["key"] for r in rows], ["d1"])
        self.assertEqual(rows[0]["instruction"], "兄弟と揃えて")
        self.assertEqual(rows[0]["fix_commit"], "abc1234")

    def test_finding_with_overrules_is_overruled_by_key_or_difit_id(self):
        for ref in ("d1", "claude-d1"):
            f = self.match(self.finding(overrules=ref))["findings"][0]
            self.assertEqual(f["decision"], "overruled")
            self.assertEqual(f["prior"]["key"], "d1")

    def test_overrules_pointing_to_non_directive_fails(self):
        enriched = run(["enrich", "--worktree", FIXTURES], json.dumps({"findings": [self.finding(overrules="d2")]}))
        p = subprocess.run([sys.executable, STATE_PY, "match", "--state", self.state_file], input=json.dumps(enriched), capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("overrules", p.stderr)

    def test_to_difit_records_overruled_as_dismissed_without_import(self):
        decided = self.match(self.finding(overrules="d1"))
        out = run(["to-difit", "--repo", "o/r", "--pr", "1", "--head-sha", "abc"], json.dumps(decided))
        self.assertEqual(out["imports"], [])
        self.assertEqual(len(out["records"]), 1)
        record = out["records"][0]
        self.assertEqual(record["status"], "dismissed")
        self.assertEqual(record["overrules"], "d1")
        self.assertIsNone(record["difit_thread_id"])
        self.assertNotEqual(record["key"], record["fingerprint"])
        self.assertIn("兄弟と揃えて", record["reason"])
        self.assertIn("abc1234", record["reason"])

    def test_overruled_record_suppresses_the_same_finding_next_time(self):
        decided = self.match(self.finding(overrules="d1"))
        out = run(["to-difit", "--repo", "o/r", "--pr", "1", "--head-sha", "abc"], json.dumps(decided))
        run(["append", "--state", self.state_file], json.dumps(out["records"]))
        f = self.match(self.finding())["findings"][0]
        self.assertEqual(f["decision"], "suppress")


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

    def test_from_github_imports_thread_whose_start_line_was_deleted(self):
        # head の更新で範囲の始点の行が消えると、GitHub は line だけを付け替え、startLine を元の行番号のまま返す
        payload = json.loads(self.payload)
        payload["threads"] = [
            {
                "id": "PRRT_stale_start", "isResolved": False, "isOutdated": False, "subjectType": "LINE",
                "path": "offset.go", "diffSide": "RIGHT", "startDiffSide": "RIGHT", "line": 13, "startLine": 16,
                "originalLine": 20, "originalStartLine": 16,
                "comments": {"nodes": [
                    {"id": "PRRC_stale_start_root", "body": "セットアップ関数を使ってください", "createdAt": "2026-09-01T00:00:00Z", "updatedAt": "2026-09-01T00:00:00Z", "author": {"login": "alice"}},
                    {"id": "PRRC_stale_start_reply", "body": "修正しました", "createdAt": "2026-09-01T01:00:00Z", "updatedAt": "2026-09-01T01:00:00Z", "author": {"login": "bob"}},
                ]},
            }
        ]
        out = run(["from-github", "--state", self.state_file, "--repo", "o/r", "--pr", "1", "--head-sha", "abc", "--worktree", FIXTURES], json.dumps(payload))
        self.assertEqual([i["id"] for i in out["imports"]], ["PRRC_stale_start_root", "PRRC_stale_start_reply"])
        self.assertEqual(out["imports"][0]["position"], {"side": "new", "line": 13})
        self.assertEqual(out["records"][0]["line"], 13)

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


class GithubThreadPositionTest(unittest.TestCase):
    """GitHub の reviewThread の位置を difit の position に変換する規則を確かめる。"""

    def thread(self, **overrides):
        base = {"diffSide": "RIGHT", "startDiffSide": "RIGHT", "line": 10, "startLine": 8, "originalLine": 10, "originalStartLine": 8}
        return {**base, **overrides}

    def test_range_moved_by_head_update_is_kept(self):
        # 始点の行が残っていれば、GitHub は line と startLine の両方を新しい行番号へ付け替える
        position = state.github_thread_position(self.thread(line=127, startLine=125, originalLine=130, originalStartLine=128))
        self.assertEqual(position, {"side": "new", "line": {"start": 125, "end": 127}})

    def test_range_whose_start_is_after_end_becomes_end_line(self):
        position = state.github_thread_position(self.thread(line=121, startLine=124, originalLine=143, originalStartLine=124))
        self.assertEqual(position, {"side": "new", "line": 121})

    def test_range_with_mismatched_start_side_becomes_end_line(self):
        position = state.github_thread_position(self.thread(startDiffSide="LEFT"))
        self.assertEqual(position, {"side": "new", "line": 10})

    def test_left_range_whose_start_is_after_end_becomes_end_line(self):
        position = state.github_thread_position(self.thread(diffSide="LEFT", startDiffSide="LEFT", originalLine=5, originalStartLine=7))
        self.assertEqual(position, {"side": "old", "line": 5})

    def test_thread_without_end_line_is_skipped(self):
        # outdated のスレッドは line が null になる
        self.assertIsNone(state.github_thread_position(self.thread(line=None, startLine=None)))


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


class ProcessedTriageTest(unittest.TestCase):
    """対応要否の返信を処理済みのスレッド (status が posted / resolved / dismissed) を分類し直さないことを確かめる。"""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state_file = os.path.join(self.tmp.name, "threads.jsonl")

    def tearDown(self):
        self.tmp.cleanup()

    def triage(self, threads):
        out = run(["triage", "--state", self.state_file], json.dumps({"threads": threads}))
        return {t["difit_thread_id"]: t for t in out["threads"]}

    def test_posted_claude_thread_before_sync_is_processed(self):
        # triage が GitHub に投稿した後も、sync で作り直すまで difit には + の返信が付いた投稿前のスレッドが残る
        state.append_records(self.state_file, [state.new_record(key="fp", origin="claude", difit_thread_id="claude-1", github_thread_id="PRRT_1", status="posted", summary="s")])
        got = self.triage([{"id": "claude-1", "filePath": "offset.go", "position": {"side": "new", "line": 14},
                            "messages": [{"id": "m1", "body": "指摘", "author": "claude"}, {"id": "m2", "body": "+ 補足", "author": None}]}])
        self.assertEqual(got["claude-1"]["classification"], "processed")
        self.assertEqual(got["claude-1"]["key"], "fp")

    def test_posted_thread_imported_from_github_is_processed(self):
        # sync の後は GitHub のスレッドを取り込むため、PR 作者の返信が最後に並ぶ
        state.append_records(self.state_file, [
            state.new_record(key="fp", origin="claude", difit_thread_id="PRRC_1", github_thread_id="PRRT_1", status="posted", summary="s"),
            state.new_record(key="user-1", origin="user", difit_thread_id="PRRC_2", github_thread_id="PRRT_2", status="posted", summary="s"),
        ])
        got = self.triage([
            {"id": "PRRC_1", "filePath": "offset.go", "position": {"side": "new", "line": 14},
             "messages": [{"id": "PRRC_1", "body": "補足\n\n---\n\n指摘", "author": "reviewer"}, {"id": "PRRC_1r", "body": "修正しました", "author": "bob"}]},
            {"id": "PRRC_2", "filePath": "offset.go", "position": {"side": "new", "line": 15},
             "messages": [{"id": "PRRC_2", "body": "err をラップして", "author": "reviewer"}, {"id": "PRRC_2r", "body": "対応しました", "author": "bob"}]},
        ])
        self.assertEqual(got["PRRC_1"]["classification"], "processed")
        self.assertEqual(got["PRRC_2"]["classification"], "processed")

    def test_resolved_and_dismissed_are_processed(self):
        # set-status の後、difit comment resolve の前に中断すると、処理済みのスレッドが difit に残る
        state.append_records(self.state_file, [
            state.new_record(key="fp", origin="claude", difit_thread_id="claude-1", status="resolved", summary="s"),
            state.new_record(key="user-1", origin="user", difit_thread_id="user-1", status="dismissed", summary="s"),
        ])
        got = self.triage([
            {"id": "claude-1", "filePath": "offset.go", "position": {"side": "new", "line": 14},
             "messages": [{"id": "m1", "body": "指摘", "author": "claude"}, {"id": "m2", "body": "+", "author": None}]},
            {"id": "user-1", "filePath": "offset.go", "position": {"side": "new", "line": 15},
             "messages": [{"id": "u1", "body": "命名が気になる", "author": None}, {"id": "u2", "body": "不要 やっぱり良い", "author": None}]},
        ])
        self.assertEqual(got["claude-1"]["classification"], "processed")
        self.assertEqual(got["user-1"]["classification"], "processed")

    def test_q_after_processing_is_to_claude(self):
        state.append_records(self.state_file, [state.new_record(key="fp", origin="claude", difit_thread_id="claude-1", github_thread_id="PRRT_1", status="posted", summary="s")])
        got = self.triage([{"id": "claude-1", "filePath": "offset.go", "position": {"side": "new", "line": 14},
                            "messages": [{"id": "m1", "body": "指摘", "author": "claude"}, {"id": "m2", "body": "+", "author": None}, {"id": "m3", "body": "q この修正で足りる？", "author": None}]}])
        self.assertEqual((got["claude-1"]["classification"], got["claude-1"]["text"]), ("to_claude", "この修正で足りる？"))

    def test_former_difit_id_maps_to_latest_record(self):
        # sync の from-github が difit_thread_id を GitHub の root comment id に置き換えても、前の id のスレッドを同じレコードに対応付ける
        prior = state.new_record(key="fp", origin="claude", difit_thread_id="claude-1", github_thread_id="PRRT_1", status="posted", summary="s")
        state.append_records(self.state_file, [prior, dict(prior, difit_thread_id="PRRC_1")])
        got = self.triage([{"id": "claude-1", "filePath": "offset.go", "position": {"side": "new", "line": 14},
                            "messages": [{"id": "m1", "body": "指摘", "author": "claude"}, {"id": "m2", "body": "+", "author": None}]}])
        self.assertEqual(got["claude-1"]["key"], "fp")
        self.assertEqual(got["claude-1"]["classification"], "processed")

    def test_github_origin_thread_keeps_existing_classification(self):
        # 他人のスレッド (origin が github) は reconcile が posted に戻すことがあるが、処理済みの扱いにしない
        state.append_records(self.state_file, [state.new_record(key="PRRT_9", origin="github", difit_thread_id="PRRC_9", github_thread_id="PRRT_9", status="posted", summary="s")])
        got = self.triage([{"id": "PRRC_9", "filePath": "offset.go", "position": {"side": "new", "line": 14},
                            "messages": [{"id": "PRRC_9", "body": "NewFlag の意味は？", "author": "alice"}]}])
        self.assertEqual(got["PRRC_9"]["classification"], "github")


class FormerDifitIdTest(unittest.TestCase):
    """sync の from-github が difit_thread_id を置き換えた後も、前の id のスレッドを同じレコードとして扱うことを確かめる。"""

    def test_register_skips_former_difit_ids(self):
        with open(os.path.join(FIXTURES, "difit-comments.json"), encoding="utf-8") as f:
            payload = f.read()
        with tempfile.TemporaryDirectory() as d:
            state_file = os.path.join(d, "threads.jsonl")
            prior = state.new_record(key="fp", origin="claude", difit_thread_id="claude-fix", github_thread_id="PRRT_1", status="posted", summary="s")
            state.append_records(state_file, [prior, dict(prior, difit_thread_id="PRRC_1")])
            out = run(["register", "--state", state_file, "--repo", "o/r", "--pr", "1", "--head-sha", "h", "--worktree", FIXTURES], payload)
        self.assertNotIn("claude-fix", {r["key"] for r in out["records"]})

    def test_rebuild_does_not_reimport_thread_replaced_by_github(self):
        # 投稿済みの指摘は from-github が GitHub のスレッドとして取り込むため、スナップショットに残る投稿前のスレッドを再投入しない
        with tempfile.TemporaryDirectory() as d:
            state_file = os.path.join(d, "threads.jsonl")
            snapshot = os.path.join(d, "difit-last.json")
            posted = state.new_record(key="fp", file="offset.go", side="new", line=14, snippet="\tif user.NewFlag {", body="指摘", origin="claude", difit_thread_id="claude-1", github_thread_id="PRRT_1", status="posted", summary="s")
            state.append_records(state_file, [posted, dict(posted, difit_thread_id="PRRC_1")])
            with open(snapshot, "w", encoding="utf-8") as f:
                json.dump({"threads": [
                    {"id": "claude-1", "filePath": "offset.go", "position": {"side": "new", "line": 14},
                     "messages": [{"id": "m1", "body": "指摘", "author": "claude"}, {"id": "m2", "body": "+", "author": None}]},
                ]}, f)
            out = run(["rebuild", "--state", state_file, "--repo", "o/r", "--pr", "1", "--head-sha", "new", "--worktree", FIXTURES, "--snapshot", snapshot])
        self.assertEqual(out["imports"], [])
        self.assertEqual(out["records"], [])

    def test_set_status_accepts_former_difit_id(self):
        # difit-fetch.sh は前の id のスレッドもレコードに対応付けるので、set-status もその id でレコードを引く
        with tempfile.TemporaryDirectory() as d:
            state_file = os.path.join(d, "threads.jsonl")
            prior = state.new_record(key="fp", origin="claude", difit_thread_id="claude-1", github_thread_id="PRRT_1", status="posted", summary="s")
            state.append_records(state_file, [prior, dict(prior, difit_thread_id="PRRC_1")])
            updated = run(["set-status", "--state", state_file, "--difit-id", "claude-1", "--status", "resolved"])
        self.assertEqual((updated["key"], updated["status"], updated["difit_thread_id"]), ("fp", "resolved", "PRRC_1"))


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


class RelocateDuplicateSnippetTest(unittest.TestCase):
    """snippet がファイル内の複数の行に一致するときに、同じ指摘の位置を 1 つに絞れることを確認する。"""

    # 5 行目と 11 行目が、空白の正規化後に同じ行になる。
    SRC = "\n".join([
        "package p",
        "",
        "func TestA(t *testing.T) {",
        "\tsetup := Input{",
        "\t\tPurchasePrice:            1000,",
        "\t\tPointValue:               2,",
        "\t}",
        "",
        "\tupdate := Input{",
        "\t\tID:            id,",
        "\t\tPurchasePrice: 1000,",
        "\t\tPointValue:    3,",
        "\t}",
        "}",
        "",
    ])
    SCOPE_A = "func TestA(t *testing.T)"
    # SRC の前に置く別の関数。3 行目が SRC の重複行と同じ行になり、SRC の各行は 6 行後ろへずれる。
    OTHER = "\n".join(["func TestB(t *testing.T) {", "\tx := Input{", "\t\tPurchasePrice: 1000,", "\t}", "}", ""])
    SCOPE_B = "func TestB(t *testing.T)"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.wt = self.tmp.name
        subprocess.run(["git", "init", "-q", self.wt], check=True)
        self.write(self.SRC)
        self.old_sha = self.commit("old")

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, src):
        with open(os.path.join(self.wt, "a_test.go"), "w", encoding="utf-8") as f:
            f.write(src)

    def commit(self, message):
        git = ["git", "-C", self.wt, "-c", "user.name=t", "-c", "user.email=t@example.com"]
        subprocess.run([*git, "add", "."], check=True)
        subprocess.run([*git, "commit", "-qm", message], check=True)
        return subprocess.run(["git", "-C", self.wt, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()

    def relocate(self, **kw):
        base = dict(key="k", file="a_test.go", side="new", line=11, snippet="\t\tPurchasePrice: 1000,", scope=self.SCOPE_A, head_sha=self.old_sha, status="open", summary="s")
        base.update(kw)
        return run(["relocate", "--worktree", self.wt], json.dumps([state.new_record(**base)]))["records"][0]

    def test_unchanged_file_keeps_the_recorded_line(self):
        out = self.relocate()
        self.assertTrue(out["relocated"])
        self.assertEqual(out["line"], 11)

    def test_recorded_line_is_kept_without_the_previous_commit(self):
        out = self.relocate(head_sha=None)
        self.assertTrue(out["relocated"])
        self.assertEqual(out["line"], 11)

    def test_context_of_the_previous_commit_wins_over_the_recorded_line(self):
        # 関数の先頭に 6 行を足すと、setup 側の行が前回の行番号 (11) へ移る。前後の行が前回と一致する update 側 (17) を選ぶ
        lines = self.SRC.split("\n")
        self.write("\n".join(lines[:3] + [f"\t// 追加 {i}" for i in range(6)] + lines[3:]))
        out = self.relocate()
        self.assertTrue(out["relocated"])
        self.assertEqual(out["line"], 17)

    def test_scope_narrows_hits_to_the_same_function(self):
        self.write(self.OTHER + "\n" + self.SRC)
        out = self.relocate(head_sha=None, line=99, scope=self.SCOPE_B)
        self.assertTrue(out["relocated"])
        self.assertEqual(out["line"], 3)

    def test_ambiguous_hits_without_evidence_are_not_relocated(self):
        # TestA の中の一致は 11 行目と 17 行目の 2 か所で、前回の行番号 (3) はどちらでもなく、前回のコミットも使えない
        self.write(self.OTHER + "\n" + self.SRC)
        out = self.relocate(head_sha=None, line=3, scope=self.SCOPE_A)
        self.assertFalse(out["relocated"])


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

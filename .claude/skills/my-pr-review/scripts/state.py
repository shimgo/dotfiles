#!/usr/bin/env python3
"""my-pr-review の状態ファイル (threads.jsonl) を操作する。

threads.jsonl は追記のみのファイルであり、同じ key を持つ行のうち最後の行を有効なレコードとみなす。
レコードの定義は reference/state.md を参照。

サブコマンド:
  enrich       findings JSON に snippet / scope / ハッシュ を付与する
  match        enrich 済み findings を状態ファイルと照合し decision を付与する
  to-difit     decision 済み findings から difit の comment import JSON とレコードを生成する
  append       標準入力の JSON 配列 (または JSONL) を状態ファイルに追記する
  latest       有効なレコードを JSON 配列で出力する
  directives   ユーザーの指示で実装した変更 (fix_commit を持つ resolved のレコード) を JSON 配列で出力する
  set-status   key を指定してレコードの status などを更新する (新しい行を追記する)
  from-github  GitHub の reviewThreads を difit import JSON とレコードに変換する
  reconcile    GitHub の reviewThreads と状態ファイルを突き合わせ、status の更新行を生成する
  triage       difit の comment get --format json の出力を分類する
  register     状態ファイルのどの行にも thread id が現れない difit のスレッド (ユーザーが書いたもの) のレコードを生成する
  relocate     有効な open レコードの位置を現在のファイル内容から特定し直す
  rebuild      difit 再構築時に再投入する import と追記行を生成する (relocate を内包する)
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import os
import re
import subprocess
import sys
import uuid

SCHEMA_VERSION = 1
CLAUDE_AUTHOR = "claude"
STATUSES = ("open", "dismissed", "posted", "resolved", "outdated")
# 対応要否の返信を処理済みの status。GitHub への投稿 (posted)、実装や指示の実行 (resolved)、対応不要の記録 (dismissed) を終えている。
PROCESSED_STATUSES = ("posted", "resolved", "dismissed")

# difit 上の返信書式。reference/reply-convention.md と一致させること。
FIX_PREFIXES = ("対応",)
DISMISS_PREFIXES = ("不要",)
# "q この記述は正しいですか？" のように 1 文字の q で始まる本文は Claude Code 宛て。質問に限らず指示も含む。
# 区切り文字を必須にするのは "query が空のとき" のような語の先頭を誤認しないためである。
TO_CLAUDE_RE = re.compile(r"^[qQ][ \t\u3000:：\n]")
# 先頭語の後に続く、無視してよい区切り文字。
SEPARATORS = " \t\u3000:：\n"
# 先頭 1 文字の省略記法。"対応" / "不要" と同じく先頭一致で判定し、続く本文は補足または理由として扱う。
SHORTHAND_PREFIXES = {"+": "fix", "-": "dismiss", "＋": "fix", "－": "dismiss", "ー": "dismiss"}


# ---------------------------------------------------------------------------
# 共通
# ---------------------------------------------------------------------------


def now_iso() -> str:
    return _dt.datetime.now().astimezone().replace(microsecond=0).isoformat()


def sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def normalize_line(line: str) -> str:
    return re.sub(r"\s+", " ", line.strip())


def normalize_snippet(snippet: str) -> str:
    return "\n".join(normalize_line(l) for l in snippet.split("\n"))


def fingerprint_of(perspective: str | None, summary: str) -> str:
    return sha256(normalize_snippet(f"{perspective or ''}\n{summary}"))


def read_json(stream=None):
    data = (stream or sys.stdin).read()
    if not data.strip():
        return None
    return json.loads(data)


def write_json(obj) -> None:
    json.dump(obj, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def line_range(line) -> tuple[int, int]:
    """difit の position.line (int または {start,end}) を (start, end) に正規化する。"""
    if isinstance(line, dict):
        return int(line["start"]), int(line["end"])
    return int(line), int(line)


def line_value(start: int, end: int):
    return start if start == end else {"start": start, "end": end}


def compact(d: dict) -> dict:
    """difit の comment import は null のフィールドを受け付けないため、None を落とす。"""
    return {k: v for k, v in d.items() if v is not None}


# ---------------------------------------------------------------------------
# 状態ファイル
# ---------------------------------------------------------------------------


def load_records(path: str) -> list[dict]:
    if not os.path.exists(path):
        return []
    records = []
    with open(path, encoding="utf-8") as f:
        for n, raw in enumerate(f, 1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                records.append(json.loads(raw))
            except json.JSONDecodeError as e:
                die(f"{path}:{n}: JSON として解釈できません: {e}")
    return records


def latest_records(records: list[dict]) -> dict[str, dict]:
    """key ごとに最後の行を有効なレコードとして返す。"""
    latest: dict[str, dict] = {}
    for r in records:
        latest[r["key"]] = r
    return latest


def records_by_difit_id(records: list[dict]) -> dict[str, dict]:
    """difit の thread id から有効なレコードを引く辞書を返す。

    sync の from-github は GitHub に投稿したレコードの difit_thread_id を GitHub の root comment id に置き換えるが、
    置き換える前の id も履歴の行に残る。停止前の difit のスナップショットや、作り直す前の difit には前の id のスレッドがあるため、
    履歴に現れたすべての id を、その key の有効なレコードに対応付ける。
    同じ id を現在の difit_thread_id に持つレコードがあれば、そちらを優先する。
    """
    latest = latest_records(records)
    by_difit: dict[str, dict] = {}
    for r in records:
        if r.get("difit_thread_id"):
            by_difit[r["difit_thread_id"]] = latest[r["key"]]
    for r in latest.values():
        if r.get("difit_thread_id"):
            by_difit[r["difit_thread_id"]] = r
    return by_difit


def append_records(path: str, records: list[dict]) -> None:
    if not records:
        return
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def new_record(**fields) -> dict:
    base = {
        "schema_version": SCHEMA_VERSION,
        "key": None,
        "repo": None,
        "pr": None,
        "head_sha": None,
        "file": None,
        "side": "new",
        "line": None,
        "scope": None,
        "snippet": None,
        "snippet_sha256": None,
        "perspective": None,
        "summary": None,
        "body": None,
        "reason": None,
        "instruction": None,
        "fix_commit": None,
        "overrules": None,
        "fingerprint": None,
        "origin": None,
        "difit_thread_id": None,
        "github_thread_id": None,
        "github_comment_id": None,
        "status": "open",
        "created_at": now_iso(),
        "updated_at": now_iso(),
    }
    base.update(fields)
    return base


# ---------------------------------------------------------------------------
# ファイル内容の取得と snippet / scope
# ---------------------------------------------------------------------------


def read_file_lines(worktree: str, file: str, side: str, base_sha: str | None, new_rev: str | None = None) -> list[str] | None:
    """side が new なら worktree のファイル (new_rev を指定すればそのコミットのファイル)、old なら base_sha のファイルを行の配列で返す。"""
    rev = base_sha if side == "old" else new_rev
    if rev:
        try:
            out = subprocess.run(
                ["git", "-C", worktree, "show", f"{rev}:{file}"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        except subprocess.CalledProcessError:
            return None
        return out.split("\n")
    if side == "old":
        return None
    path = os.path.join(worktree, file)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read().split("\n")


def extract_snippet(lines: list[str], start: int, end: int) -> str | None:
    if start < 1 or end > len(lines) or start > end:
        return None
    return "\n".join(lines[start - 1 : end])


def extract_scope(lines: list[str], start: int, file: str) -> str | None:
    """Go ファイルに限り、指摘行を囲む関数のシグネチャを返す。

    gofmt 済みであることを前提に、行頭が非空白の行をトップレベル宣言とみなす。
    """
    if not file.endswith(".go"):
        return None
    if start < 1 or start > len(lines):
        return None
    line = lines[start - 1]
    if line and not line[0].isspace():
        return None
    for i in range(start - 2, -1, -1):
        candidate = lines[i]
        if candidate and not candidate[0].isspace():
            if candidate.startswith("func "):
                return re.sub(r"\s*\{\s*$", "", candidate.rstrip())
            return None
    return None


def enrich_one(item: dict, worktree: str, base_sha: str | None, new_rev: str | None = None) -> dict:
    side = item.get("side") or "new"
    start, end = line_range(item["line"])
    lines = read_file_lines(worktree, item["file"], side, base_sha, new_rev)
    snippet = extract_snippet(lines, start, end) if lines else None
    scope = extract_scope(lines, start, item["file"]) if lines else None
    out = dict(item)
    out["side"] = side
    out["line"] = line_value(start, end)
    out["snippet"] = snippet
    out["snippet_sha256"] = sha256(normalize_snippet(snippet)) if snippet is not None else None
    out["scope"] = scope
    out["fingerprint"] = fingerprint_of(item.get("perspective"), item["summary"])
    return out


# ---------------------------------------------------------------------------
# 照合
# ---------------------------------------------------------------------------


def is_directive(record: dict) -> bool:
    """ユーザーの指示で実装した変更のレコードかを返す。triage のケース 2 が fix_commit を記録する。"""
    return record.get("status") == "resolved" and bool(record.get("fix_commit"))


def find_directive(ref: str, records: list[dict]) -> dict | None:
    """findings の overrules が指すレコードを key または difit の thread id から引く。"""
    latest = latest_records(records)
    target = latest.get(ref) or records_by_difit_id(records).get(ref)
    if target is None or not is_directive(target):
        return None
    return target


def decide(finding: dict, latest: dict[str, dict]) -> tuple[str, dict | None]:
    """3 段階の照合ロジック。reference/state.md を参照。

    戻り値は (decision, prior)。decision は suppress / annotate / report。
    overrules を持つ指摘は cmd_match がこの関数より先に overruled と判定する。
    """
    same_snippet = [
        r
        for r in latest.values()
        if r.get("file") == finding["file"]
        and r.get("snippet_sha256")
        and r.get("snippet_sha256") == finding.get("snippet_sha256")
    ]
    if same_snippet:
        same_perspective = [r for r in same_snippet if r.get("perspective") == finding.get("perspective")]
        if same_perspective:
            return "suppress", newest(same_perspective)
        return "annotate", newest(same_snippet)
    if finding.get("scope"):
        same_scope = [
            r
            for r in latest.values()
            if r.get("file") == finding["file"]
            and r.get("scope") == finding["scope"]
            and r.get("fingerprint") == finding["fingerprint"]
        ]
        if same_scope:
            return "annotate", newest(same_scope)
    return "report", None


def newest(records: list[dict]) -> dict:
    return sorted(records, key=lambda r: r.get("updated_at") or "")[-1]


def annotation_for(prior: dict) -> str:
    label = {
        "dismissed": "対応不要と判断済み",
        "resolved": "GitHub 上で解決済み",
        "posted": "GitHub に投稿済み",
        "open": "既出",
        "outdated": "位置を特定できなくなった指摘",
    }.get(prior.get("status"), prior.get("status"))
    parts = [f"> 過去の判断: {label}"]
    if prior.get("summary"):
        parts.append(f"> 過去の指摘: {prior['summary']}")
    if prior.get("reason"):
        parts.append(f"> 理由: {prior['reason']}")
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# GitHub reviewThreads の変換 (difit の cli/github.js の規則に、範囲を表せないスレッドの扱いだけを変えて従う)
# ---------------------------------------------------------------------------


def github_thread_position(thread: dict) -> dict | None:
    """GitHub の reviewThread の位置を difit の position に変換する。終了行を持たないスレッドは None を返す。

    difit で表せない複数行の範囲 (始点が終了行より後・始点が正の整数でない・始点と終了行の side が違う) を持つスレッドは、
    GitHub がコメントを表示する終了行の 1 行として返す。difit の cli/github.js はこのスレッドを捨てるが、ここでは捨てない。
    GitHub は head の更新で範囲の始点の行が消えると、終了行 (line) だけを新しい行番号へ付け替え、始点 (startLine) を元の行番号のまま返す。
    その結果 startLine が line を超えても、GitHub は isOutdated を false のまま返すため、未解決のスレッドは from-github の取り込み対象に残る。
    捨てると、sync が作り直した difit はそのスレッドを表示しない。
    """

    def positive(v):
        return isinstance(v, int) and v > 0

    side = thread.get("diffSide")
    if side == "RIGHT":
        line, start = thread.get("line"), thread.get("startLine")
        start_side = thread.get("startDiffSide")
        if not positive(line):
            return None
        redundant = start is not None and start == line and start_side is None
        multi = start_side is not None if start_side is not None else (start is not None and not redundant)
        if not multi:
            return {"side": "new", "line": line}
        if start_side != "RIGHT" or not positive(start) or start > line:
            return {"side": "new", "line": line}
        return {"side": "new", "line": {"start": start, "end": line}}
    if side == "LEFT":
        line, start = thread.get("originalLine"), thread.get("originalStartLine")
        start_side = thread.get("startDiffSide")
        if not positive(line):
            return None
        redundant = start is not None and start == line and start_side is None
        multi = start_side is not None if start_side is not None else (start is not None and not redundant)
        if not multi:
            return {"side": "old", "line": line}
        if start_side != "LEFT" or not positive(start) or start > line:
            return {"side": "old", "line": line}
        return {"side": "old", "line": {"start": start, "end": line}}
    return None


def github_thread_to_imports(thread: dict) -> list[dict]:
    position = github_thread_position(thread)
    if position is None:
        return []
    comments = sorted(thread.get("comments", {}).get("nodes", []), key=lambda c: c.get("createdAt") or "")
    imports = []
    for i, c in enumerate(comments):
        imports.append(
            compact(
                {
                    "type": "thread" if i == 0 else "reply",
                    "id": c["id"],
                    "filePath": thread["path"],
                    "position": position,
                    "body": c.get("body") or "",
                    "author": (c.get("author") or {}).get("login"),
                    "createdAt": c.get("createdAt"),
                    "updatedAt": c.get("updatedAt"),
                }
            )
        )
    return imports


# ---------------------------------------------------------------------------
# difit スレッドの分類
# ---------------------------------------------------------------------------


def classify_reply(body: str) -> tuple[str, str]:
    """返信本文を (種別, 残りの本文) に分類する。種別は fix / dismiss / to_claude / other。

    other は q も + も - も付いていない本文で、レビュイーへのコメントとして扱う。
    """
    text = body.strip()
    if TO_CLAUDE_RE.match(text):
        return "to_claude", text[1:].lstrip(SEPARATORS)
    if text and text[0] in SHORTHAND_PREFIXES:
        return SHORTHAND_PREFIXES[text[0]], text[1:].lstrip(SEPARATORS)
    for prefixes, kind in ((DISMISS_PREFIXES, "dismiss"), (FIX_PREFIXES, "fix")):
        for p in prefixes:
            if not text.startswith(p):
                continue
            rest = text[len(p) :]
            if rest and rest[0] not in SEPARATORS:
                continue  # "不要な変数が残っている" のように語の一部なら先頭語ではない
            return kind, rest.lstrip(SEPARATORS)
    return "other", text


def is_claude(message: dict) -> bool:
    return (message.get("author") or "") == CLAUDE_AUTHOR


def strip_annotation(body: str) -> str:
    """to-difit が先頭に付けた過去の判断の注記 ("> " で始まる行) を取り除く。GitHub には載せない内部情報のため。"""
    lines = body.split("\n")
    i = 0
    while i < len(lines) and lines[i].startswith("> "):
        i += 1
    if i == 0:
        return body
    return "\n".join(lines[i:]).lstrip("\n")


def is_bare_directive(body: str) -> bool:
    """"+" や "対応" のように、意思表示だけで本文を持たない返信か。"""
    kind, rest = classify_reply(body)
    return kind in ("fix", "dismiss") and rest == ""


def is_to_claude(body: str) -> bool:
    """Claude Code 宛ての本文 ("q ...") か。レビュイーに見せる本文には含めない。"""
    return classify_reply(body)[0] == "to_claude"


def directive_stripped_body(body: str) -> str:
    """先頭語 ("+" / "-" / "対応" / "不要") を取り除いた本文を返す。先頭語が無ければ本文をそのまま返す。

    レビュイーは対応要否の表明そのものを読む必要がないため、GitHub へ載せる本文からは先頭語を落とす。
    """
    kind, rest = classify_reply(body)
    return rest if kind in ("fix", "dismiss") else body.strip()


def github_body(root: dict, replies: list[dict]) -> str:
    """GitHub のレビューコメント本文を組み立てる。

    Claude の指摘に対しては「ユーザーの返信 --- Claude の指摘 (注記を除く)」の順にする。
    ユーザー自身のスレッドは本文をそのまま使う (返信は含めない)。
    Claude Code 宛ての本文 ("q ...") はレビュイー宛てではないので含めない。
    ユーザー自身のスレッドの本文が "q ..." だけの場合は空文字列を返し、投稿する前に本文を書き直させる。
    """
    user_texts = [
        directive_stripped_body(m.get("body") or "")
        for m in replies
        if not is_claude(m)
        and (m.get("body") or "").strip()
        and not is_bare_directive(m.get("body") or "")
        and not is_to_claude(m.get("body") or "")
    ]
    root_body = (root.get("body") or "").strip()
    if not is_claude(root):
        # author が無いものだけがユーザー自身の書き込み。GitHub から取り込んだスレッドの本文はそのまま使う。
        return "" if (not root.get("author") and is_to_claude(root_body)) else root_body
    root_body = strip_annotation(root_body)
    if not user_texts:
        return root_body
    return "\n\n".join(user_texts) + "\n\n---\n\n" + root_body


def triage_thread(thread: dict, record: dict | None) -> dict:
    messages = thread.get("messages") or []
    root = messages[0] if messages else {"body": "", "author": None}
    replies = messages[1:]
    origin = record["origin"] if record else ("github" if str(thread["id"]).startswith("PRRC_") else "user")
    if record is None and is_claude(root):
        origin = "claude"

    result = {
        "difit_thread_id": thread["id"],
        "file": thread["filePath"],
        "position": thread["position"],
        "origin": origin,
        "key": record["key"] if record else None,
        "status": record["status"] if record else None,
        "root_author": root.get("author"),
        "root_body": root.get("body") or "",
        "replies": [{"author": m.get("author"), "body": m.get("body") or ""} for m in replies],
        "classification": "none",
        "text": "",
        "github_body": github_body(root, replies),
    }

    last = messages[-1] if messages else None
    if last is not None and is_claude(last) and len(messages) > 1:
        # Claude が最後に発言したスレッドは、次のユーザー返信を待つ状態
        return result

    if record is not None and origin in ("claude", "user") and record.get("status") in PROCESSED_STATUSES:
        # 対応要否の返信は triage (指示なら answer) で処理済みのため、分類し直さない。
        # 分類し直すと、GitHub に投稿した指摘を重複して投稿したり、実装済みの指摘を再び実装したりする。
        # GitHub に投稿した後の difit には、sync で作り直すまで投稿前のスレッドが、作り直した後は PR 作者の返信が付いた GitHub のスレッドが並ぶ。
        # 処理した後に書いた Claude Code 宛ての本文 ("q ...") だけを answer の対象にする。
        kind, rest = classify_reply(last.get("body") or "") if len(messages) > 1 else ("other", "")
        if kind == "to_claude":
            result["classification"] = "to_claude"
            result["text"] = rest
        else:
            result["classification"] = "processed"
        return result

    if origin == "claude":
        user_replies = [m for m in replies if not is_claude(m)]
        if not user_replies:
            result["classification"] = "pending"
            return result
        kind, rest = classify_reply(user_replies[-1].get("body") or "")
        # q も + も - も付かない返信はレビュイーへのコメントなので、指摘と一緒に GitHub へ投稿する
        result["classification"] = "fix" if kind == "other" else kind
        result["text"] = rest
        return result

    # ユーザー起点、または GitHub 由来のスレッド
    kind, rest = classify_reply(root.get("body") or "")
    if kind == "to_claude" and not replies:
        result["classification"] = "to_claude"
        result["text"] = rest
        return result
    if replies:
        last_user = [m for m in replies if not is_claude(m)]
        if last_user:
            kind2, rest2 = classify_reply(last_user[-1].get("body") or "")
            if kind2 in ("to_claude", "dismiss", "fix"):
                result["classification"] = kind2
                result["text"] = rest2
                return result
    result["classification"] = "user_finding" if origin == "user" else "github"
    return result


# ---------------------------------------------------------------------------
# relocate
# ---------------------------------------------------------------------------


# 前回の位置と比べる前後の行数。
RELOCATE_CONTEXT_LINES = 5


def snippet_hits(lines: list[str], target: list[str]) -> list[int]:
    """正規化した snippet の行 (target) と一致する位置の開始行 (1 始まり) をすべて返す。"""
    n = len(target)
    return [i + 1 for i in range(len(lines) - n + 1) if [normalize_line(l) for l in lines[i : i + n]] == target]


def context_score(previous: list[str], previous_start: int, current: list[str], current_start: int, n: int) -> int:
    """前回のファイルの previous_start と現在のファイルの current_start から始まる n 行について、前後の行がいくつ一致するかを返す。"""
    score = 0
    for d in range(1, RELOCATE_CONTEXT_LINES + 1):
        for p, c in ((previous_start - 1 - d, current_start - 1 - d), (previous_start - 2 + n + d, current_start - 2 + n + d)):
            if 0 <= p < len(previous) and 0 <= c < len(current) and normalize_line(previous[p]) == normalize_line(current[c]):
                score += 1
    return score


def narrow_hits(record: dict, lines: list[str], hits: list[int], target: list[str], worktree: str, base_sha: str | None) -> list[int]:
    """snippet が複数の位置に一致したとき、同じ指摘の位置を 1 つに絞る。絞れなければ候補を複数のまま返す。

    空白を正規化した 1 行の snippet は、同じファイルの別の箇所 (字下げや揃えの空白だけが違う行) にも一致しやすい。
    行番号は照合に使わないが、候補が複数あるときに限り、次の順で絞る。
      1. scope (指摘を囲む Go の関数) が同じ候補に絞る
      2. 前回位置を確かめたコミット (head_sha) のファイルの、前回の行に snippet があれば、前後の行の一致が最も多い候補に絞る
      3. 前回の行に snippet がまだあれば、その候補に絞る
    どれでも絞れないときに近い候補を選ぶことはしない。別の行へ付け替えるより、outdated にして verify で確かめるほうが安全なためである。
    """
    if record.get("scope"):
        scoped = [h for h in hits if extract_scope(lines, h, record["file"]) == record["scope"]]
        if scoped:
            hits = scoped
    if len(hits) <= 1 or record.get("line") is None:
        return hits

    start, _ = line_range(record["line"])
    n = len(target)
    if (record.get("side") or "new") == "new" and record.get("head_sha"):
        previous = read_file_lines(worktree, record["file"], "new", base_sha, record["head_sha"])
        # 前回のコミットに前回の行の snippet が無ければ (未コミットの変更を見ていたなど)、前回の前後の行として使えない
        if previous is not None and start in snippet_hits(previous, target):
            scores = {h: context_score(previous, start, lines, h, n) for h in hits}
            best = max(scores.values())
            hits = [h for h in hits if scores[h] == best]
    if len(hits) > 1 and start in hits:
        return [start]
    return hits


def relocate_record(record: dict, worktree: str, base_sha: str | None = None) -> dict:
    """snippet を現在のファイル (side が old なら base_sha のファイル) から探し、位置を 1 つに決められれば line を更新する。

    snippet が複数の位置に一致したときは narrow_hits で絞る。
    """
    out = dict(record)
    if not record.get("snippet"):
        out["relocated"] = False
        return out
    lines = read_file_lines(worktree, record["file"], record.get("side") or "new", base_sha)
    if lines is None:
        out["relocated"] = False
        return out
    target = [normalize_line(l) for l in record["snippet"].split("\n")]
    hits = snippet_hits(lines, target)
    if len(hits) > 1:
        hits = narrow_hits(record, lines, hits, target, worktree, base_sha)
    if len(hits) == 1:
        out["line"] = line_value(hits[0], hits[0] + len(target) - 1)
        out["relocated"] = True
    else:
        out["relocated"] = False
    return out


# ---------------------------------------------------------------------------
# サブコマンド
# ---------------------------------------------------------------------------


def cmd_enrich(a):
    payload = read_json() or {}
    findings = payload["findings"] if isinstance(payload, dict) else payload
    write_json({"findings": [enrich_one(f, a.worktree, a.base_sha) for f in findings]})


def cmd_match(a):
    payload = read_json() or {}
    findings = payload["findings"] if isinstance(payload, dict) else payload
    records = load_records(a.state)
    latest = latest_records(records)
    out = []
    for f in findings:
        if f.get("overrules"):
            # ユーザーの指示で実装した変更を覆す指摘は投稿しない。指す先が指示の記録でなければ、付け間違いを見逃さないよう中断する
            directive = find_directive(f["overrules"], records)
            if directive is None:
                die(f"overrules が指すレコードがユーザーの指示で実装した変更ではありません: {f['overrules']} (state.py directives で確認してください)")
            decision, prior = "overruled", directive
        else:
            decision, prior = decide(f, latest)
        item = dict(f)
        item["decision"] = decision
        item["prior"] = prior
        out.append(item)
    write_json({"findings": out})


def cmd_to_difit(a):
    payload = read_json() or {}
    findings = payload["findings"] if isinstance(payload, dict) else payload
    imports, records = [], []
    for f in findings:
        if f.get("decision") == "suppress":
            continue
        # key は指摘ごとに一意にする。fingerprint は観点と要約だけから作るため、別の箇所への同じ文面の指摘で重なり、
        # key にすると後の行が前の行を上書きして片方の記録が消える。
        thread_id = f"claude-{uuid.uuid4().hex[:12]}"
        if f.get("decision") == "overruled":
            # difit には投稿せず、対応不要の記録だけを残す。次回以降は同じ箇所・同じ観点の照合でも抑止できる
            prior = f.get("prior") or {}
            records.append(
                new_record(
                    key=thread_id,
                    repo=a.repo,
                    pr=a.pr,
                    head_sha=a.head_sha,
                    file=f["file"],
                    side=f.get("side") or "new",
                    line=f["line"],
                    scope=f.get("scope"),
                    snippet=f.get("snippet"),
                    snippet_sha256=f.get("snippet_sha256"),
                    perspective=f.get("perspective"),
                    summary=f["summary"],
                    body=f["body"],
                    reason=f"ユーザーの指示で実装した変更を覆す指摘のため投稿しない (指示: {prior.get('instruction') or '+'} / 元の指摘: {prior.get('summary')} / コミット: {prior.get('fix_commit')})",
                    overrules=prior.get("key"),
                    fingerprint=f["fingerprint"],
                    origin="claude",
                    status="dismissed",
                )
            )
            continue
        body = f["body"]
        if f.get("decision") == "annotate" and f.get("prior"):
            body = annotation_for(f["prior"]) + "\n\n" + body
        imports.append(
            {
                "type": "thread",
                "id": thread_id,
                "filePath": f["file"],
                "position": {"side": f.get("side") or "new", "line": f["line"]},
                "body": body,
                "author": CLAUDE_AUTHOR,
            }
        )
        records.append(
            new_record(
                key=thread_id,
                repo=a.repo,
                pr=a.pr,
                head_sha=a.head_sha,
                file=f["file"],
                side=f.get("side") or "new",
                line=f["line"],
                scope=f.get("scope"),
                snippet=f.get("snippet"),
                snippet_sha256=f.get("snippet_sha256"),
                perspective=f.get("perspective"),
                summary=f["summary"],
                body=body,
                fingerprint=f["fingerprint"],
                origin="claude",
                difit_thread_id=thread_id,
                status="open",
            )
        )
    write_json({"imports": imports, "records": records})


def cmd_append(a):
    raw = sys.stdin.read()
    if not raw.strip():
        return
    stripped = raw.lstrip()
    if stripped.startswith("["):
        records = json.loads(raw)
    elif stripped.startswith("{") and "\n" not in stripped.strip():
        records = [json.loads(raw)]
    else:
        records = [json.loads(l) for l in raw.splitlines() if l.strip()]
    for r in records:
        if not r.get("key"):
            die("key のないレコードは追記できません")
        if r.get("status") not in STATUSES:
            die(f"不正な status: {r.get('status')}")
    append_records(a.state, records)
    print(f"appended {len(records)} record(s) to {a.state}", file=sys.stderr)


def cmd_latest(a):
    latest = latest_records(load_records(a.state))
    rows = list(latest.values())
    if a.status:
        rows = [r for r in rows if r.get("status") in a.status]
    if a.origin:
        rows = [r for r in rows if r.get("origin") in a.origin]
    write_json(rows)


def cmd_directives(a):
    rows = [r for r in latest_records(load_records(a.state)).values() if is_directive(r)]
    rows.sort(key=lambda r: r.get("updated_at") or "")
    write_json(
        [
            {k: r.get(k) for k in ("key", "difit_thread_id", "file", "scope", "perspective", "summary", "body", "instruction", "fix_commit")}
            for r in rows
        ]
    )


def cmd_set_status(a):
    records = load_records(a.state)
    latest = latest_records(records)
    target = None
    if a.key:
        target = latest.get(a.key)
    elif a.difit_id:
        # difit-fetch.sh の difit_thread_id をそのまま渡せるよう、triage と同じく置き換える前の id でも引く
        target = records_by_difit_id(records).get(a.difit_id)
    elif a.github_id:
        target = next((r for r in latest.values() if r.get("github_thread_id") == a.github_id), None)
    if target is None:
        die("対象のレコードが見つかりません")
    updated = dict(target)
    if a.status:
        updated["status"] = a.status
    if a.reason is not None:
        updated["reason"] = a.reason
    if a.instruction is not None:
        updated["instruction"] = a.instruction
    if a.fix_commit:
        updated["fix_commit"] = a.fix_commit
    if a.github_thread_id:
        updated["github_thread_id"] = a.github_thread_id
    if a.github_comment_id:
        updated["github_comment_id"] = a.github_comment_id
    if a.set_difit_id:
        updated["difit_thread_id"] = a.set_difit_id
    if a.head_sha:
        updated["head_sha"] = a.head_sha
    updated["updated_at"] = now_iso()
    append_records(a.state, [updated])
    write_json(updated)


def cmd_from_github(a):
    payload = read_json() or {}
    threads = payload["threads"] if isinstance(payload, dict) else payload
    latest = latest_records(load_records(a.state))
    by_github_id = {r["github_thread_id"]: r for r in latest.values() if r.get("github_thread_id")}
    imports, records = [], []
    for t in threads:
        if t.get("subjectType") not in (None, "LINE"):
            continue
        if t.get("isOutdated"):
            continue
        thread_imports = github_thread_to_imports(t)
        if not thread_imports:
            continue
        root_comment_id = thread_imports[0]["id"]
        existing = by_github_id.get(t["id"])
        if not t.get("isResolved") or a.include_resolved:
            imports.extend(thread_imports)
        if existing is not None:
            if existing.get("difit_thread_id") != root_comment_id:
                updated = dict(existing)
                updated["difit_thread_id"] = root_comment_id
                updated["updated_at"] = now_iso()
                records.append(updated)
            continue
        position = thread_imports[0]["position"]
        start, end = line_range(position["line"])
        root = thread_imports[0]
        item = {"file": t["path"], "side": position["side"], "line": position["line"], "summary": (root["body"] or "").strip().split("\n")[0][:200], "perspective": None}
        enriched = enrich_one(item, a.worktree, a.base_sha) if a.worktree else dict(item, snippet=None, snippet_sha256=None, scope=None, fingerprint=fingerprint_of(None, item["summary"]))
        records.append(
            new_record(
                key=t["id"],
                repo=a.repo,
                pr=a.pr,
                head_sha=a.head_sha,
                file=t["path"],
                side=position["side"],
                line=position["line"],
                scope=enriched.get("scope"),
                snippet=enriched.get("snippet"),
                snippet_sha256=enriched.get("snippet_sha256"),
                summary=item["summary"],
                body=root["body"],
                fingerprint=enriched["fingerprint"],
                origin="github",
                difit_thread_id=root_comment_id,
                github_thread_id=t["id"],
                github_comment_id=root_comment_id,
                status="resolved" if t.get("isResolved") else "open",
            )
        )
    write_json({"imports": imports, "records": records})


def cmd_reconcile(a):
    payload = read_json() or {}
    threads = payload["threads"] if isinstance(payload, dict) else payload
    pending = bool(payload.get("viewer_pending_review_id")) if isinstance(payload, dict) else False
    by_id = {t["id"]: t for t in threads}
    latest = latest_records(load_records(a.state))
    updates, warnings = [], []
    for r in latest.values():
        gid = r.get("github_thread_id")
        if not gid:
            continue
        t = by_id.get(gid)
        if t is None:
            if pending:
                warnings.append(f"{r['key']}: GitHub にスレッドが見つかりませんが pending review が残っているため判断を保留します")
                continue
            if r["status"] != "dismissed":
                u = dict(r, status="dismissed", reason=r.get("reason") or "レビュアーが GitHub のレビュー送信前にコメントを削除した", updated_at=now_iso())
                updates.append(u)
            continue
        if t.get("isResolved") and r["status"] != "resolved":
            updates.append(dict(r, status="resolved", updated_at=now_iso()))
        elif not t.get("isResolved") and r["status"] == "resolved":
            updates.append(dict(r, status="posted", updated_at=now_iso()))
    write_json({"records": updates, "warnings": warnings})


def cmd_triage(a):
    payload = read_json() or {}
    threads = payload["threads"] if isinstance(payload, dict) else payload
    by_difit = records_by_difit_id(load_records(a.state))
    out = [triage_thread(t, by_difit.get(t["id"])) for t in threads]
    write_json({"threads": out})


def cmd_relocate(a):
    payload = read_json()
    records = payload if isinstance(payload, list) else (payload or {}).get("records", [])
    write_json({"records": [relocate_record(r, a.worktree, a.base_sha) for r in records]})


def register_threads(threads: list[dict], by_difit: dict[str, dict], a, new_rev: str | None = None) -> list[dict]:
    """difit にあって状態ファイルに無いスレッドを、ユーザー (または Claude) のスレッドとして記録するレコードを作る。

    by_difit には records_by_difit_id の戻り値を渡す。置き換える前の difit_thread_id のスレッドも既知として扱い、記録し直さないためである。
    """
    new_records = []
    for t in threads:
        if t["id"] in by_difit:
            continue
        messages = t.get("messages") or []
        root = messages[0] if messages else {"body": "", "author": None}
        origin = "claude" if is_claude(root) else "user"
        position = t["position"]
        item = {
            "file": t["filePath"],
            "side": position.get("side") or "new",
            "line": position["line"],
            "summary": (root.get("body") or "").strip().split("\n")[0][:200],
            "perspective": None,
        }
        enriched = enrich_one(item, a.worktree, a.base_sha, new_rev)
        new_records.append(
            new_record(
                key=t["id"],
                repo=a.repo,
                pr=a.pr,
                head_sha=new_rev or a.head_sha,
                file=item["file"],
                side=item["side"],
                line=enriched["line"],
                scope=enriched.get("scope"),
                snippet=enriched.get("snippet"),
                snippet_sha256=enriched.get("snippet_sha256"),
                summary=item["summary"],
                body=root.get("body") or "",
                fingerprint=enriched["fingerprint"],
                origin=origin,
                difit_thread_id=t["id"],
                status="open",
            )
        )
    return new_records


def cmd_register(a):
    """difit の comment get --format json の出力を読み、状態ファイルに無いスレッドのレコードを出力する。"""
    payload = read_json() or {}
    threads = payload["threads"] if isinstance(payload, dict) else payload
    write_json({"records": register_threads(threads, records_by_difit_id(load_records(a.state)), a)})


def cmd_rebuild(a):
    """difit を作り直すときに再投入する import と、状態ファイルへの追記行を生成する。

    対象は GitHub に投稿していない open なスレッド。snapshot (停止前の difit の comment get 出力) が
    あれば、状態ファイルに無いスレッドをユーザーのものとして記録し、返信も一緒に再投入する。
    GitHub に投稿した指摘は from-github が GitHub のスレッドとして取り込むため、snapshot に残る投稿前のスレッドは再投入しない。
    """
    records = load_records(a.state)
    latest = latest_records(records)
    snapshot_threads: list[dict] = []
    if a.snapshot and os.path.exists(a.snapshot):
        with open(a.snapshot, encoding="utf-8") as f:
            snapshot_threads = (json.load(f) or {}).get("threads", [])
    snapshot_by_id = {t["id"]: t for t in snapshot_threads}
    by_difit = {r["difit_thread_id"]: r for r in latest.values() if r.get("difit_thread_id")}

    # sync は from-github の追記を終えてから rebuild を実行するため、投稿済みのレコードの difit_thread_id は GitHub の id に置き換わっている。
    # snapshot の投稿前のスレッドを状態ファイルに無いものと誤認しないよう、置き換える前の id も既知として扱う。
    new_records = register_threads(snapshot_threads, records_by_difit_id(records), a, a.snapshot_head_sha)
    for rec in new_records:
        by_difit[rec["difit_thread_id"]] = rec

    imports, updates, outdated = [], [], []
    now = now_iso()
    for r in by_difit.values():
        if r.get("status") != "open" or r.get("github_thread_id"):
            continue
        rel = relocate_record(r, a.worktree, a.base_sha)
        if not rel.pop("relocated", False):
            outdated.append({"key": r["key"], "file": r.get("file"), "summary": r.get("summary")})
            updates.append(dict(r, status="outdated", updated_at=now))
            continue
        position = {"side": r.get("side") or "new", "line": rel["line"]}
        imports.append(
            compact(
                {
                    "type": "thread",
                    "id": r["difit_thread_id"],
                    "filePath": r["file"],
                    "position": position,
                    "body": r.get("body") or "",
                    "author": CLAUDE_AUTHOR if r.get("origin") == "claude" else None,
                }
            )
        )
        for m in (snapshot_by_id.get(r["difit_thread_id"], {}).get("messages") or [])[1:]:
            imports.append(
                compact(
                    {
                        "type": "reply",
                        "id": m.get("id"),
                        "filePath": r["file"],
                        "position": position,
                        "body": m.get("body") or "",
                        "author": m.get("author"),
                        "createdAt": m.get("createdAt"),
                    }
                )
            )
        updates.append(dict(rel, head_sha=a.head_sha, updated_at=now))
    write_json({"imports": imports, "records": new_records + updates, "outdated": outdated})


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="command", required=True)

    s = sub.add_parser("enrich")
    s.add_argument("--worktree", required=True)
    s.add_argument("--base-sha")
    s.set_defaults(func=cmd_enrich)

    s = sub.add_parser("match")
    s.add_argument("--state", required=True)
    s.set_defaults(func=cmd_match)

    s = sub.add_parser("to-difit")
    s.add_argument("--repo", required=True)
    s.add_argument("--pr", type=int, required=True)
    s.add_argument("--head-sha", required=True)
    s.set_defaults(func=cmd_to_difit)

    s = sub.add_parser("append")
    s.add_argument("--state", required=True)
    s.set_defaults(func=cmd_append)

    s = sub.add_parser("latest")
    s.add_argument("--state", required=True)
    s.add_argument("--status", action="append", choices=STATUSES)
    s.add_argument("--origin", action="append", choices=("claude", "user", "github"))
    s.set_defaults(func=cmd_latest)

    s = sub.add_parser("directives")
    s.add_argument("--state", required=True)
    s.set_defaults(func=cmd_directives)

    s = sub.add_parser("set-status")
    s.add_argument("--state", required=True)
    g = s.add_mutually_exclusive_group(required=True)
    g.add_argument("--key")
    g.add_argument("--difit-id")
    g.add_argument("--github-id")
    s.add_argument("--status", choices=STATUSES)
    s.add_argument("--reason")
    s.add_argument("--instruction", help="実装を指示したユーザーの返信の本文 (先頭語を除く)。+ だけなら空文字")
    s.add_argument("--fix-commit", help="ユーザーの指示を実装したコミットのハッシュ。これを持つ resolved のレコードを directives が返す")
    s.add_argument("--github-thread-id")
    s.add_argument("--github-comment-id")
    s.add_argument("--set-difit-id")
    s.add_argument("--head-sha")
    s.set_defaults(func=cmd_set_status)

    s = sub.add_parser("from-github")
    s.add_argument("--state", required=True)
    s.add_argument("--repo", required=True)
    s.add_argument("--pr", type=int, required=True)
    s.add_argument("--head-sha", required=True)
    s.add_argument("--worktree")
    s.add_argument("--base-sha")
    s.add_argument("--include-resolved", action="store_true")
    s.set_defaults(func=cmd_from_github)

    s = sub.add_parser("reconcile")
    s.add_argument("--state", required=True)
    s.set_defaults(func=cmd_reconcile)

    s = sub.add_parser("triage")
    s.add_argument("--state", required=True)
    s.set_defaults(func=cmd_triage)

    s = sub.add_parser("relocate")
    s.add_argument("--worktree", required=True)
    s.add_argument("--base-sha")
    s.set_defaults(func=cmd_relocate)

    s = sub.add_parser("register")
    s.add_argument("--state", required=True)
    s.add_argument("--repo", required=True)
    s.add_argument("--pr", type=int, required=True)
    s.add_argument("--head-sha", required=True)
    s.add_argument("--worktree", required=True)
    s.add_argument("--base-sha")
    s.set_defaults(func=cmd_register)

    s = sub.add_parser("rebuild")
    s.add_argument("--state", required=True)
    s.add_argument("--repo", required=True)
    s.add_argument("--pr", type=int, required=True)
    s.add_argument("--head-sha", required=True)
    s.add_argument("--worktree", required=True)
    s.add_argument("--base-sha")
    s.add_argument("--snapshot", help="停止前の difit の comment get --format json の出力ファイル")
    s.add_argument("--snapshot-head-sha", help="スナップショット取得時の head。状態ファイルに無いスレッドの snippet はこのコミットから読む")
    s.set_defaults(func=cmd_rebuild)

    a = p.parse_args(argv)
    a.func(a)


if __name__ == "__main__":
    main()

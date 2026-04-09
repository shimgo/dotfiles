#!/usr/bin/env python3
"""
現在の Claude Code セッションのトークン使用量アナライザ。

~/.claude/projects/<encoded-cwd>/ 配下の最新 JSONL を読み取り、以下を出力する:
  - USD 推定コスト（モデル別の内蔵価格表を参照）
  - 実トークン使用量の合計（assistant.message.usage の集計）
  - カテゴリ別の内訳推定（各ブロックの文字数 × コンテキスト残存ターン数）
  - 単発サイズが大きいブロックのトップ（「1 回の巨大 Read」型アンチパターン検出用）

内訳推定から除外: システムプロンプト と CLAUDE.md（JSONL に記録されないため）。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

PROJECTS_DIR = Path.home() / ".claude" / "projects"

# 日本語の大まかな文字範囲: ひらがな・カタカナ・CJK 統合漢字・全角記号
JP_RE = re.compile(r"[\u3040-\u30ff\u3400-\u9fff\uff00-\uffef]")

# 2026-04 時点の Anthropic 公開単価（USD / 1M tokens）。
# 単価が変わったらここを直接編集する。標準 200k コンテキスト単価のみ対応しており、
# 1M コンテキスト変種で 200k 超リクエストが 2 倍課金される件は未対応。
PRICING = {
    "opus": {
        "input":      15.00,
        "output":     75.00,
        "cache_w_5m": 18.75,
        "cache_w_1h": 30.00,
        "cache_r":     1.50,
    },
    "sonnet": {
        "input":       3.00,
        "output":     15.00,
        "cache_w_5m":  3.75,
        "cache_w_1h":  6.00,
        "cache_r":     0.30,
    },
    "haiku": {
        "input":       1.00,
        "output":      5.00,
        "cache_w_5m":  1.25,
        "cache_w_1h":  2.00,
        "cache_r":     0.10,
    },
}


def pick_pricing(model: str | None) -> dict | None:
    """モデル名に含まれる 'opus' / 'sonnet' / 'haiku' キーワードで PRICING を選択する。"""
    if not model:
        return None
    m = model.lower()
    for key in ("opus", "sonnet", "haiku"):
        if key in m:
            return PRICING[key]
    return None


def encode_cwd(cwd: str) -> str:
    """Claude Code のプロジェクト dir 名エンコード規則に合わせて '/' と '.' を '-' に置換する。"""
    return re.sub(r"[/.]", "-", cwd)


def find_session_jsonl(cwd: str, session_id: str | None) -> Path | None:
    """対象 cwd のプロジェクト dir から、指定セッション、もしくは mtime 最新の JSONL を返す。"""
    proj_dir = PROJECTS_DIR / encode_cwd(cwd)
    if not proj_dir.is_dir():
        return None
    if session_id:
        path = proj_dir / f"{session_id}.jsonl"
        return path if path.exists() else None
    candidates = [p for p in proj_dir.glob("*.jsonl") if p.is_file()]
    if not candidates:
        return None
    return max(candidates, key=lambda p: p.stat().st_mtime)


def estimate_tokens_from_text(text: str) -> int:
    """文字列から推定トークン数を返す。日本語: 2 文字/1tok、その他: 4 文字/1tok。"""
    if not text:
        return 0
    jp = sum(1 for c in text if JP_RE.match(c))
    other = len(text) - jp
    return jp // 2 + other // 4


def estimate_tokens(obj) -> int:
    """任意の content（str / list / dict）を JSON シリアライズしてから文字数でトークン数を推定する。"""
    if obj is None:
        return 0
    if isinstance(obj, str):
        return estimate_tokens_from_text(obj)
    try:
        s = json.dumps(obj, ensure_ascii=False)
    except (TypeError, ValueError):
        s = str(obj)
    return estimate_tokens_from_text(s)


# --- 分類 ---

# ツール名 -> (カテゴリラベル, tool_use の input dict から詳細文字列を取り出す関数)
TOOL_CATEGORY = {
    "Read":       ("Read",        lambda i: i.get("file_path", "")),
    "Bash":       ("Bash出力",    lambda i: (i.get("description") or i.get("command", ""))[:60]),
    "Grep":       ("検索",        lambda i: f"grep {i.get('pattern', '')[:40]}"),
    "Glob":       ("検索",        lambda i: f"glob {i.get('pattern', '')[:40]}"),
    "WebFetch":   ("Web取得",     lambda i: i.get("url", "")),
    "WebSearch":  ("Web取得",     lambda i: f"search {i.get('query', '')[:40]}"),
    "Task":       ("Agent結果",   lambda i: i.get("subagent_type") or i.get("description", "")),
    "Agent":      ("Agent結果",   lambda i: i.get("subagent_type") or i.get("description", "")),
}


def classify_tool_result(tool_name: str, tool_input: dict) -> tuple[str, str]:
    """tool_result をカテゴリラベルと詳細ラベルに分類する。未知のツールは「ツール: <name>」扱い。"""
    if tool_name in TOOL_CATEGORY:
        cat, extractor = TOOL_CATEGORY[tool_name]
        try:
            return cat, extractor(tool_input or {})
        except Exception:
            return cat, ""
    return f"ツール: {tool_name}", ""


ATTACHMENT_CATEGORY = {
    "skill_listing":         "スキル一覧",
    "deferred_tools_delta":  "遅延ツール定義",
    "task_reminder":         "タスクリマインダ",
}


# --- パーサ ---

def parse_session(jsonl_path: Path) -> dict:
    """JSONL を走査し、ブロック単位のレコードと実 usage の合計を返す。"""
    real_usage = defaultdict(int)
    blocks = []  # 要素は {turn, side, category, detail, tokens} の dict
    tool_use_index: dict[str, tuple[str, dict]] = {}
    model_counter: Counter = Counter()
    current_turn = 0

    with open(jsonl_path) as f:
        lines = f.readlines()

    # 1 パス目: tool_use_id -> (ツール名, input) のマッピングを先に作る
    for line in lines:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "assistant":
            for c in obj.get("message", {}).get("content", []) or []:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    tool_use_index[c.get("id", "")] = (
                        c.get("name", ""),
                        c.get("input", {}) or {},
                    )

    for line in lines:
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get("type")

        if msg_type == "assistant":
            current_turn += 1
            msg = obj.get("message", {}) or {}
            usage = msg.get("usage", {}) or {}
            for k in (
                "input_tokens",
                "cache_creation_input_tokens",
                "cache_read_input_tokens",
                "output_tokens",
            ):
                real_usage[k] += int(usage.get(k, 0) or 0)

            # cache_creation の 5min / 1h 内訳
            cc = usage.get("cache_creation") or {}
            if isinstance(cc, dict):
                real_usage["cache_creation_5m"] += int(cc.get("ephemeral_5m_input_tokens", 0) or 0)
                real_usage["cache_creation_1h"] += int(cc.get("ephemeral_1h_input_tokens", 0) or 0)

            model = msg.get("model")
            if model:
                model_counter[model] += 1

            for c in msg.get("content", []) or []:
                if not isinstance(c, dict):
                    continue
                ctype = c.get("type")
                if ctype in ("text", "thinking"):
                    text = c.get("text") or c.get("thinking") or ""
                    blocks.append({
                        "turn": current_turn,
                        "side": "assistant",
                        "category": "アシスタント応答",
                        "detail": "",
                        "tokens": estimate_tokens_from_text(text),
                    })
                elif ctype == "tool_use":
                    blocks.append({
                        "turn": current_turn,
                        "side": "assistant",
                        "category": f"ツール呼び出し: {c.get('name', '?')}",
                        "detail": "",
                        "tokens": estimate_tokens(c.get("input", {})),
                    })

        elif msg_type == "user":
            content = obj.get("message", {}).get("content", "")
            replay_turn = current_turn + 1

            if isinstance(content, str):
                blocks.append({
                    "turn": replay_turn,
                    "side": "user",
                    "category": "ユーザーメッセージ",
                    "detail": "",
                    "tokens": estimate_tokens_from_text(content),
                })
                continue

            if not isinstance(content, list):
                continue

            for c in content:
                if not isinstance(c, dict):
                    continue
                ctype = c.get("type")
                if ctype == "text":
                    blocks.append({
                        "turn": replay_turn,
                        "side": "user",
                        "category": "ユーザーメッセージ",
                        "detail": "",
                        "tokens": estimate_tokens_from_text(c.get("text", "")),
                    })
                elif ctype == "tool_result":
                    tool_use_id = c.get("tool_use_id", "")
                    tname, tinput = tool_use_index.get(tool_use_id, ("", {}))
                    cat, detail = classify_tool_result(tname, tinput)
                    inner = c.get("content", "")
                    blocks.append({
                        "turn": replay_turn,
                        "side": "user",
                        "category": cat,
                        "detail": detail,
                        "tokens": estimate_tokens(inner),
                    })

        elif msg_type == "attachment":
            replay_turn = current_turn + 1
            att = obj.get("attachment", {}) or {}
            atype = att.get("type", "unknown")
            label = ATTACHMENT_CATEGORY.get(atype, f"アタッチメント: {atype}")
            blocks.append({
                "turn": replay_turn,
                "side": "user",
                "category": label,
                "detail": "",
                "tokens": estimate_tokens(att),
            })

        elif msg_type == "file-history-snapshot":
            replay_turn = current_turn + 1
            blocks.append({
                "turn": replay_turn,
                "side": "user",
                "category": "ファイル履歴スナップショット",
                "detail": "",
                "tokens": estimate_tokens(obj.get("snapshot")),
            })

    total_turns = current_turn + 1  # まだ返答していない現在ターンも含める

    # (カテゴリ, 詳細) キーで集約する
    agg_cum: dict[tuple[str, str], int] = defaultdict(int)
    agg_count: dict[tuple[str, str], int] = defaultdict(int)
    agg_max_single: dict[tuple[str, str], int] = defaultdict(int)
    for b in blocks:
        if b["side"] == "user":
            repeats = max(0, total_turns - b["turn"] + 1)
        else:
            repeats = max(0, total_turns - b["turn"])
        key = (b["category"], b["detail"])
        agg_cum[key] += b["tokens"] * repeats
        agg_count[key] += 1
        if b["tokens"] > agg_max_single[key]:
            agg_max_single[key] = b["tokens"]

    aggregated = [
        {
            "category": k[0],
            "detail": k[1],
            "tokens": agg_cum[k],
            "count": agg_count[k],
            "max_single": agg_max_single[k],
        }
        for k in agg_cum
    ]

    # 単発サイズが大きいブロックのトップ 10（集約前の生ブロックから抽出）
    top_single = sorted(blocks, key=lambda b: b["tokens"], reverse=True)[:10]

    return {
        "jsonl_path": str(jsonl_path),
        "session_id": jsonl_path.stem,
        "assistant_turns": current_turn,
        "model": model_counter.most_common(1)[0][0] if model_counter else None,
        "models": dict(model_counter),
        "real_usage": dict(real_usage),
        "aggregated": aggregated,
        "top_single_blocks": top_single,
    }


# --- 出力 ---

def fmt(n: int) -> str:
    return f"{n:,}"


def fmt_usd(amount: float) -> str:
    if amount >= 1.0:
        return f"${amount:,.2f}"
    return f"${amount:.4f}"


def render_markdown(result: dict, top_n: int = 10) -> str:
    """parse_session の結果を Markdown 文字列に整形する。"""
    real = result["real_usage"]
    real_input_total = (
        real.get("input_tokens", 0)
        + real.get("cache_creation_input_tokens", 0)
        + real.get("cache_read_input_tokens", 0)
    )
    real_output_total = real.get("output_tokens", 0)
    real_grand_total = real_input_total + real_output_total
    turns = result["assistant_turns"] or 1

    rows = sorted(result["aggregated"], key=lambda x: x["tokens"], reverse=True)
    estimated_input_total = sum(r["tokens"] for r in rows)
    residual = max(real_input_total - estimated_input_total, 0)
    denom = real_input_total or 1
    top = rows[:top_n]

    model = result.get("model")
    pricing = pick_pricing(model)

    lines: list[str] = []
    lines.append("## セッション トークン使用状況")
    lines.append("")
    lines.append(f"- セッション: `{result['session_id']}`")
    lines.append(f"- モデル: `{model or '(unknown)'}`")
    lines.append(f"- assistantターン数: {result['assistant_turns']}")
    if len(result.get("models") or {}) > 1:
        mixed = ", ".join(f"{k}×{v}" for k, v in result["models"].items())
        lines.append(f"- 複数モデル混在: {mixed}")
    lines.append("")

    # --- コストセクション ---
    if pricing:
        cw_5m = real.get("cache_creation_5m", 0)
        cw_1h = real.get("cache_creation_1h", 0)
        cw_total = real.get("cache_creation_input_tokens", 0)
        breakdown_missing = False
        if cw_5m + cw_1h == 0 and cw_total > 0:
            cw_5m = cw_total
            breakdown_missing = True

        cost_input = real.get("input_tokens", 0) / 1e6 * pricing["input"]
        cost_cw5m = cw_5m / 1e6 * pricing["cache_w_5m"]
        cost_cw1h = cw_1h / 1e6 * pricing["cache_w_1h"]
        cost_cr = real.get("cache_read_input_tokens", 0) / 1e6 * pricing["cache_r"]
        cost_out = real_output_total / 1e6 * pricing["output"]
        cost_total = cost_input + cost_cw5m + cost_cw1h + cost_cr + cost_out

        # キャッシュを全く使わなかった場合の仮想コスト（全入力を base rate で課金）
        no_cache = real_input_total / 1e6 * pricing["input"] + real_output_total / 1e6 * pricing["output"]
        savings_pct = (1 - cost_total / no_cache) * 100 if no_cache > 0 else 0
        per_turn = cost_total / turns

        def _pct(x: float) -> str:
            return f"{x / cost_total * 100:.1f}%" if cost_total > 0 else "-"

        lines.append("### 推定コスト")
        lines.append("")
        lines.append("| 種別 | トークン | USD | 割合 |")
        lines.append("|---|---:|---:|---:|")
        lines.append(f"| input (新規) | {fmt(real.get('input_tokens', 0))} | {fmt_usd(cost_input)} | {_pct(cost_input)} |")
        lines.append(f"| cache write (5min) | {fmt(cw_5m)} | {fmt_usd(cost_cw5m)} | {_pct(cost_cw5m)} |")
        lines.append(f"| cache write (1h) | {fmt(cw_1h)} | {fmt_usd(cost_cw1h)} | {_pct(cost_cw1h)} |")
        lines.append(f"| cache read | {fmt(real.get('cache_read_input_tokens', 0))} | {fmt_usd(cost_cr)} | {_pct(cost_cr)} |")
        lines.append(f"| output | {fmt(real_output_total)} | {fmt_usd(cost_out)} | {_pct(cost_out)} |")
        lines.append(f"| **合計** | | **{fmt_usd(cost_total)}** | 100.0% |")
        lines.append(f"| 参考: キャッシュ無しの場合 | | {fmt_usd(no_cache)}（削減率 {savings_pct:.1f}%） | - |")
        lines.append("")
        lines.append(f"- ターンあたり平均: {fmt_usd(per_turn)} / turn")
        if breakdown_missing:
            lines.append("- ※ cache_creation の 5m/1h 内訳が JSONL に無いため、全量を 5m として計算しています")
        lines.append("- ※ 標準 200k コンテキスト単価で計算。1M コンテキスト変種では 200k 超リクエストが 2 倍課金される場合があります")
        lines.append("")
    else:
        lines.append("### 推定コスト")
        lines.append("")
        lines.append(f"- モデル `{model}` の単価が PRICING テーブルに無いためスキップ")
        lines.append("")

    # --- 実測 usage ---
    lines.append("### 実測トークン (assistant.usage)")
    lines.append("")
    lines.append(f"- input_tokens: {fmt(real.get('input_tokens', 0))}")
    lines.append(f"- cache_creation_input_tokens: {fmt(real.get('cache_creation_input_tokens', 0))} "
                 f"(5min: {fmt(real.get('cache_creation_5m', 0))} / 1h: {fmt(real.get('cache_creation_1h', 0))})")
    lines.append(f"- cache_read_input_tokens: {fmt(real.get('cache_read_input_tokens', 0))}")
    lines.append(f"- output_tokens: {fmt(real_output_total)}")
    lines.append(f"- 入力合計: {fmt(real_input_total)} / 出力合計: {fmt(real_output_total)} / 全体: {fmt(real_grand_total)}")
    lines.append("")

    # --- カテゴリ別内訳トップ N ---
    lines.append(f"### 累計入力トークンの内訳推定（トップ{top_n} + 計測不可分）")
    lines.append("")
    lines.append("| # | カテゴリ | 詳細 | 出現 | 単発最大 | 累計 | 構成比 |")
    lines.append("|---|---|---|---:|---:|---:|---:|")
    for i, r in enumerate(top, 1):
        share = r["tokens"] / denom * 100
        detail = r["detail"] or "-"
        if len(detail) > 50:
            detail = detail[:47] + "..."
        lines.append(
            f"| {i} | {r['category']} | {detail} | {r['count']}回 | ~{fmt(r['max_single'])} | ~{fmt(r['tokens'])} | {share:.1f}% |"
        )
    if residual > 0:
        share = residual / denom * 100
        lines.append(
            f"| - | 計測不可 | システムプロンプト / ツール定義 / CLAUDE.md など "
            f"| - | - | ~{fmt(residual)} | {share:.1f}% |"
        )
    lines.append("")
    lines.append(f"- JSONL から推定できた累計入力: ~{fmt(estimated_input_total)}")
    lines.append(f"- 計測不可の残差: ~{fmt(residual)}")
    lines.append("")

    # --- 単発サイズが大きいブロック ---
    top_single = result.get("top_single_blocks", [])[:5]
    if top_single:
        lines.append("### 単発サイズが大きいブロック（トップ5）")
        lines.append("")
        lines.append("1 回の出現で重いブロック。「巨大ファイルを 1 回読んだ」型の単発消費の検出用。")
        lines.append("")
        lines.append("| # | カテゴリ | 詳細 | 単発トークン | 出現ターン |")
        lines.append("|---|---|---|---:|---:|")
        for i, b in enumerate(top_single, 1):
            detail = b.get("detail") or "-"
            if len(detail) > 50:
                detail = detail[:47] + "..."
            lines.append(
                f"| {i} | {b['category']} | {detail} | ~{fmt(b['tokens'])} | turn {b['turn']} |"
            )
        lines.append("")

    lines.append("> 注: 実測値は assistant.message.usage の合計です。USD コストは 2026-04 時点の Anthropic 公開単価に基づく推定。")
    lines.append("> カテゴリ別の数値は各ブロックの文字数 × コンテキスト残存ターン数で算出した推定で、")
    lines.append("> システムプロンプト・ツール定義・CLAUDE.md は JSONL に記録されないため「計測不可」として表示しています。")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cwd", default=None, help="調査対象の cwd（デフォルト: 現在のディレクトリ）")
    parser.add_argument("--session", default=None, help="明示指定するセッション ID（デフォルト: mtime 最新）")
    parser.add_argument("--top", type=int, default=10, help="カテゴリ別内訳の表示行数")
    parser.add_argument("--json", action="store_true", help="Markdown ではなく構造化 JSON を出力する")
    args = parser.parse_args(argv)

    cwd = args.cwd or str(Path.cwd())
    jsonl = find_session_jsonl(cwd, args.session)
    if not jsonl:
        print(
            f"error: {PROJECTS_DIR / encode_cwd(cwd)} 配下にセッション JSONL が見つかりません",
            file=sys.stderr,
        )
        return 1

    result = parse_session(jsonl)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(result, top_n=args.top))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

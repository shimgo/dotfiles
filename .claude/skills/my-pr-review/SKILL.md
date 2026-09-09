---
name: my-pr-review
description: |
  GitHub の PR を difit (ローカルの diff ビューア) 上でレビューし、Claude の指摘とユーザーのコメントを difit と GitHub の間で往復させる個人用のレビューワークフロー。
  次のような依頼のときに必ず使う: 「この PR をレビューして difit で見せて」「PR #1234 のレビューセッションを始めて」「difit の返信を見て対応して」
  「difit のコメントを GitHub に反映して」「GitHub の最新コメントを difit に同期して」「指摘が直ったか確認して resolve して」「セルフレビューを始めて」
  「再指摘防止リスト」「対応不要にした指摘」「レビューの続き」など、PR レビューを difit や再指摘防止リストと組み合わせて進める文脈なら、
  ユーザーがスキル名を挙げなくても使う。単に「このコードをレビューして」と言われただけで difit も PR も出てこない場合は使わない。
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Skill", "Edit", "Write", "AskUserQuestion"]
---

# my-pr-review

PR レビューを difit と GitHub の間で往復させるワークフロー。状態は GitHub (レビュー送信後の正本) と
`~/.local/state/claude/review/<owner>/<repo>/pr-<番号>/` (session.json と threads.jsonl) の 2 か所だけに置き、
difit は表示層として毎ラウンド作り直す。設計の背景は `reference/state.md` を参照。

## フェーズの選び方

引数の先頭語、または依頼内容から 1 つ選び、対応する手順書を読んでから作業する。
セッションを開いたまま工程を進めるときは `next` を使う。

| フェーズ | 手順書 | 使う場面 |
| --- | --- | --- |
| `next` | (下記) | 次の工程へ進む。difit の状態と直前のフェーズから次のフェーズを判定して実行する |
| `start` | `phases/start.md` | レビュー依頼を受けた、または自分の PR を作った直後。worktree と difit とセッションを準備する |
| `review` | `phases/review.md` | リポジトリ固有のレビュースキルを実行し、指摘を difit に投稿する。再レビューもここ |
| `answer` | `phases/answer.md` | ユーザーが difit 上に書いた質問に返信する |
| `triage` | `phases/triage.md` | ユーザーが difit 上で付けた対応要否を処理する。GitHub への pending 投稿や実装もここ |
| `sync` | `phases/sync.md` | レビュー送信後や PR 作者の修正後に、GitHub の状態を取り込んで difit を作り直す |
| `verify` | `phases/verify.md` | 指摘が修正されたかを確認し、GitHub と difit の両方で resolve する |

### `next` の動き

```bash
$SKILL_DIR/scripts/next.sh <state-dir>
```

を実行し、出力の `phase` に対応する手順書に従う。`phase` が `wait` のときは実行するものが無いので、`reason` を伝えて終わる
(ユーザーが difit で対応要否を付けている途中、または GitHub で pending review を送信していない)。
判定は difit の未処理の返信と `session.json` の `last_phase` から行うので、各フェーズの最後に必ず `scripts/phase-done.sh` を実行して `last_phase` を更新する。
「レビューの続きをして」のように曖昧な依頼も `next` として扱う。

## 全体像

ケース 1 (他人の PR) と ケース 2 (自分の PR) で流れが違うのは triage 以降だけである。

```
start → review ─┬→ answer (随時)
                └→ triage ─┬→ ケース1: GitHub pending 投稿 → (ユーザーが GitHub 上で送信) → sync → verify → review …
                           └→ ケース2: 実装とコミット → review (差分のみ) → triage …
```

## 共通の約束

- **`$SKILL_DIR`** は手順書中で `~/.claude/skills/my-pr-review` を指す。スクリプトはすべてこの下の `scripts/` にある。
- **状態ディレクトリ** は `scripts/common.sh` の `state_dir_for` が決める。以降のスクリプトはすべて第 1 引数に状態ディレクトリを取る。
  `session.json` の `state_dir` にも同じ値が入っているので、迷ったらそこを読む。
- **difit 上のスレッドは resolve すると消える。** resolved という状態は difit に存在しない。
  したがって resolve や削除の前に必ず `state.py set-status` で記録を残す。順序を逆にすると判断が失われる。
- **Claude が difit に書くときは `author` を `claude` にする。** `scripts/state.py` はこの値でユーザーの発言と区別する。
  返信を直接 `difit comment add` で書く場合も `"author":"claude"` を付ける。
- **ユーザーの返信書式** は `reference/reply-convention.md` に従って解釈する。書式に合わない返信は `unclear` として扱い、勝手に判断せずユーザーに確認する。
- **GitHub へ書き込むのは pending review へのコメント追加と resolve だけ**。レビューの送信 (submit) はユーザーが GitHub 上で行う。
- **作業ディレクトリ**: リポジトリ固有のレビュースキルは現在のディレクトリを対象にする。ケース 1 では worktree で Claude Code を起動しているか、
  `session.json` の `worktree` と現在のディレクトリが一致しているかを review の前に確認する。
- 秘密情報 (トークン、鍵、パスワード) を difit のコメントやコマンド引数に含めない。

## スクリプト一覧

| スクリプト | 役割 |
| --- | --- |
| `scripts/session-start.sh <PR> [--local] [--review-skill NAME]` | セッション開始。worktree、difit、GitHub スレッドの取り込み |
| `scripts/difit-post.sh <state-dir> <findings.json>` | 指摘を照合して difit に投稿し、記録する |
| `scripts/difit-fetch.sh <state-dir> [--raw]` | difit のスレッドを取得し、返信を分類する |
| `scripts/github-pending.sh <state-dir> < items.json` | difit のスレッドを GitHub の pending review に追加する |
| `scripts/github-resolve.sh <state-dir> <thread-id>...` | GitHub のスレッドを resolve する |
| `scripts/sync.sh <state-dir> [--no-restart]` | GitHub との突き合わせと difit の再構築 |
| `scripts/next.sh <state-dir>` | 次のフェーズを判定する |
| `scripts/phase-done.sh <state-dir> <phase>` | フェーズの完了を session.json に記録する |
| `scripts/state.py <subcommand>` | 状態ファイルの操作。`--help` で一覧 |

スクリプトの出力は JSON なので、結果をユーザーに伝えるときは件数と対象を日本語で要約する。

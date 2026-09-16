#!/usr/bin/env bash
# my-pr-review のスクリプトが共有する関数。各スクリプトから source して使う。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_PY="${SCRIPT_DIR}/state.py"
STATE_ROOT="${XDG_STATE_HOME:-${HOME}/.local/state}/claude/review"

need() {
  for cmd in "$@"; do
    command -v "${cmd}" >/dev/null 2>&1 || { echo "error: ${cmd} が見つかりません" >&2; exit 1; }
  done
}

# 状態ディレクトリ: <STATE_ROOT>/<owner>/<repo>/pr-<番号>
state_dir_for() {
  local repo="$1" pr="$2"
  echo "${STATE_ROOT}/${repo}/pr-${pr}"
}

# 引数で渡された状態ディレクトリを検証し、session.json の各値を変数に読み込む。
load_session() {
  STATE_DIR="$1"
  SESSION="${STATE_DIR}/session.json"
  STATE_FILE="${STATE_DIR}/threads.jsonl"
  [ -f "${SESSION}" ] || { echo "error: ${SESSION} がありません。session-start.sh を先に実行してください" >&2; exit 1; }
  REPO="$(jq -r '.repo' "${SESSION}")"
  PR="$(jq -r '.pr' "${SESSION}")"
  PR_URL="$(jq -r '.pr_url' "${SESSION}")"
  MODE="$(jq -r '.mode' "${SESSION}")"
  WORKTREE="$(jq -r '.worktree' "${SESSION}")"
  BASE_REF="$(jq -r '.base_ref' "${SESSION}")"
  HEAD_REF="$(jq -r '.head_ref' "${SESSION}")"
  BASE_SHA="$(jq -r '.base_sha' "${SESSION}")"
  HEAD_SHA="$(jq -r '.head_sha' "${SESSION}")"
  REVIEWED_HEAD_SHA="$(jq -r '.reviewed_head_sha // empty' "${SESSION}")"
  DIFIT_PORT="$(jq -r '.difit.port // empty' "${SESSION}")"
  DIFIT_PID="$(jq -r '.difit.pid // empty' "${SESSION}")"
  REVIEW_SKILL="$(jq -r '.review_skill // empty' "${SESSION}")"
}

difit_alive() {
  # /api/heartbeat は接続を保持し続けるため使わない
  [ -n "${DIFIT_PORT:-}" ] && curl -sf --max-time 5 "http://localhost:${DIFIT_PORT}/api/comments-json" >/dev/null 2>&1
}

# difit をバックグラウンドで起動し、{"port","url","pid"} の JSON を返す。
#
# local モード (自分の PR のセルフレビュー) では head ではなく作業ツリー (".") を、base には origin/<base_ref> を --merge-base で渡す。
# 指摘へ対応するたびにコミットしなくても差分へ反映されるうえ、difit の画面で選べる "origin/<base_ref>...Uncommitted Changes (merge-base)" と
# 同じ対象になる。difit はコメントを差分の対象ごとに持つため、起動時の対象と画面で選ぶ対象がずれるとコメントが表示されない。
# worktree モード (他人の PR) は他人の head を detach で見ているだけなので、head と base の SHA をそのまま対象にする。
start_difit() {
  local worktree="$1" head="$2" base="$3" mode="${4:-worktree}" base_ref="${5:-}"
  if [ "${mode}" = "local" ] && [ -n "${base_ref}" ]; then
    (cd "${worktree}" && difit . "origin/${base_ref}" --merge-base --background --clean)
    return
  fi
  (cd "${worktree}" && difit "${head}" "${base}" --background --clean)
}

# difit --background は起動を待たずに JSON を返すため、API が応答するまで待ってから import する。
# 待たずに import すると、起動前の投入が捨てられて difit が空のまま立ち上がる (返信ごと失う)。
wait_difit_ready() {
  local port="$1" i
  for i in $(seq 1 50); do
    if curl -sf --max-time 2 "http://localhost:${port}/api/comments-json" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  echo "error: difit (port ${port}) が 10 秒以内に応答しませんでした" >&2
  return 1
}

# difit が使える状態になったことを URL 付きで標準エラーへ知らせる。
# 呼び出し側のスクリプトが GitHub の取り込みを終えるのを待たずに、Claude がこの行を読んで URL をユーザーへ伝えられるようにする。
announce_difit_url() {
  echo "difit ready: $1" >&2
}

stop_difit() {
  local pid="$1"
  if [ -n "${pid}" ] && kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
  fi
}

# JSON 配列を difit に投入する。空配列なら何もしない。
# difit の応答 ({"success":...}) は呼び出し元の JSON 出力と混ざらないよう標準エラーに流す。
difit_import() {
  local port="$1" json="$2"
  if [ "$(printf '%s' "${json}" | jq 'length')" -gt 0 ]; then
    printf '%s' "${json}" | difit comment add --port "${port}" >&2
  fi
}

# session.json の一部を更新する。引数は jq のフィルタ。
update_session() {
  local filter="$1"
  local tmp
  tmp="$(mktemp)"
  jq "${filter}" "${SESSION}" > "${tmp}" && mv "${tmp}" "${SESSION}"
}

#!/usr/bin/env bash
# sync が位置を特定できずに outdated にしたスレッドを、指定した行で difit に戻す。
#
# 使い方: difit-restore.sh <状態ディレクトリ> <key> <行 (12 または 12-14)> [<ファイル>]
#
# 行は Claude がコードを読んで決める (phases/restore.md)。rebuild が状態ファイルに残した発言 (root と返信) を
# 再投入し、レコードの status を open に戻して位置と snippet を指定した行のものに置き換える。
# ファイルを移動した場合は、第 4 引数に移動先のファイル (リポジトリルートからの相対パス) を渡す。省略するとレコードのファイルに戻す。
#
# 出力 (JSON): 戻したレコードの key、file、line と、再投入した発言の件数

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need jq difit python3 curl
load_session "$1"
KEY="${2:?key を指定してください}"
LINE="${3:?行を指定してください (12 または 12-14)}"
FILE_ARGS=()
[ -n "${4:-}" ] && FILE_ARGS=(--file "$4")

difit_alive || { echo "error: difit が停止しています。sync.sh で作り直してから実行してください" >&2; exit 1; }

# bash 3.2 は set -u の下で空の配列を "${FILE_ARGS[@]}" と展開するとエラーにするため、要素があるときだけ展開する
RESTORED="$(python3 "${STATE_PY}" restore --state "${STATE_FILE}" --key "${KEY}" --line "${LINE}" ${FILE_ARGS[@]+"${FILE_ARGS[@]}"} \
  --head-sha "${HEAD_SHA}" --worktree "${WORKTREE}" --base-sha "${BASE_SHA}")"
difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${RESTORED}")"
jq -c '.records' <<<"${RESTORED}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

jq '{key: .records[0].key, file: .records[0].file, line: .records[0].line, messages: (.imports | length)}' <<<"${RESTORED}"

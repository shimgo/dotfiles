#!/usr/bin/env bash
# difit 上のスレッドを取得し、返信内容を分類して返す。
#
# 使い方: difit-fetch.sh <状態ディレクトリ> [--raw]
# --raw を付けると difit の出力をそのまま返す (状態ファイルへの登録もしない)。
# 分類の意味は reference/reply-convention.md を参照。

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need jq difit python3 curl
load_session "$1"
difit_alive || { echo "error: difit (port ${DIFIT_PORT}) に接続できません。sync.sh で再起動してください" >&2; exit 1; }

RAW="$(difit comment get --port "${DIFIT_PORT}" --format json)"
if [ "${2:-}" = "--raw" ]; then
  printf '%s\n' "${RAW}"
  exit 0
fi
# ユーザーが difit 上で直接書いたスレッドを状態ファイルに登録しておく。
# difit を作り直しても失わないため、また set-status で参照できるようにするため。
printf '%s' "${RAW}" | python3 "${STATE_PY}" register --state "${STATE_FILE}" --repo "${REPO}" --pr "${PR}" \
  --head-sha "${HEAD_SHA}" --worktree "${WORKTREE}" --base-sha "${BASE_SHA}" \
  | jq -c '.records' | python3 "${STATE_PY}" append --state "${STATE_FILE}"
printf '%s' "${RAW}" | python3 "${STATE_PY}" triage --state "${STATE_FILE}"

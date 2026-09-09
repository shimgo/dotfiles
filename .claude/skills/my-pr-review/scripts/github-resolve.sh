#!/usr/bin/env bash
# GitHub の review thread を resolve し、状態ファイルの status を resolved にする。
#
# 使い方: github-resolve.sh <状態ディレクトリ> <github_thread_id>...

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh jq python3
load_session "$1"; shift

for TID in "$@"; do
  gh api graphql -F id="${TID}" -f query='
mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { id isResolved } } }' \
    | jq -c '.data.resolveReviewThread.thread'
  python3 "${STATE_PY}" set-status --state "${STATE_FILE}" --github-id "${TID}" --status resolved >/dev/null 2>&1 \
    || echo "warning: ${TID} に対応するレコードが状態ファイルにありません" >&2
done

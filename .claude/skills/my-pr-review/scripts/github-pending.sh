#!/usr/bin/env bash
# difit 上のスレッドを GitHub の pending review にコメントとして追加し、状態ファイルに記録する。
#
# 使い方: github-pending.sh <状態ディレクトリ> < items.json
# items.json: [{"difit_thread_id": "...", "body": "..."}] の配列。
#   位置 (file / side / line) は difit の現在のスレッドから取得する。
#   状態ファイルにレコードがないスレッド (ユーザーが difit 上で直接書いたもの) はレコードを新規に作る。
#
# 出力: [{"difit_thread_id", "key", "github_thread_id", "github_comment_id"}]

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh jq difit python3 curl
load_session "$1"
difit_alive || { echo "error: difit (port ${DIFIT_PORT}) に接続できません" >&2; exit 1; }

ITEMS="$(cat)"
DIFIT_THREADS="$(difit comment get --port "${DIFIT_PORT}" --format json | jq -c '.threads')"

OWNER="${REPO%%/*}"; NAME="${REPO##*/}"
INFO="$(gh api graphql -F owner="${OWNER}" -F repo="${NAME}" -F number="${PR}" -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  viewer { login }
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) { id reviews(first: 20, states: PENDING) { nodes { id author { login } } } }
  }
}')"
PR_ID="$(jq -r '.data.repository.pullRequest.id' <<<"${INFO}")"
VIEWER="$(jq -r '.data.viewer.login' <<<"${INFO}")"
REVIEW_ID="$(jq -r --arg v "${VIEWER}" '[.data.repository.pullRequest.reviews.nodes[] | select(.author.login == $v) | .id][0] // empty' <<<"${INFO}")"
if [ -z "${REVIEW_ID}" ]; then
  REVIEW_ID="$(gh api graphql -F prId="${PR_ID}" -f query='
mutation($prId: ID!) { addPullRequestReview(input: {pullRequestId: $prId}) { pullRequestReview { id } } }' \
    | jq -r '.data.addPullRequestReview.pullRequestReview.id')"
  echo "info: pending review ${REVIEW_ID} を作成しました" >&2
fi

RESULTS='[]'
for row in $(jq -r '.[] | @base64' <<<"${ITEMS}"); do
  ITEM="$(base64 --decode <<<"${row}")"
  TID="$(jq -r '.difit_thread_id' <<<"${ITEM}")"
  BODY="$(jq -r '.body' <<<"${ITEM}")"
  THREAD="$(jq -c --arg id "${TID}" '.[] | select(.id == $id)' <<<"${DIFIT_THREADS}")"
  [ -n "${THREAD}" ] || { echo "warning: difit にスレッド ${TID} がありません。スキップします" >&2; continue; }
  FILE="$(jq -r '.filePath' <<<"${THREAD}")"
  SIDE="$(jq -r 'if .position.side == "old" then "LEFT" else "RIGHT" end' <<<"${THREAD}")"
  START="$(jq -r 'if (.position.line|type) == "object" then .position.line.start else .position.line end' <<<"${THREAD}")"
  END="$(jq -r 'if (.position.line|type) == "object" then .position.line.end else .position.line end' <<<"${THREAD}")"

  VARS="$(jq -n --arg rid "${REVIEW_ID}" --arg path "${FILE}" --arg side "${SIDE}" --argjson line "${END}" --argjson start "${START}" --arg body "${BODY}" \
    '{reviewId:$rid, path:$path, side:$side, line:$line, body:$body} + (if $start != $line then {startLine:$start, startSide:$side} else {} end)')"
  MUTATION='
mutation($reviewId: ID!, $path: String!, $side: DiffSide!, $line: Int!, $body: String!, $startLine: Int, $startSide: DiffSide) {
  addPullRequestReviewThread(input: {pullRequestReviewId: $reviewId, path: $path, side: $side, line: $line, body: $body, startLine: $startLine, startSide: $startSide}) {
    thread { id comments(first: 1) { nodes { id } } }
  }
}'
  RES="$(jq -n --arg q "${MUTATION}" --argjson v "${VARS}" '{query:$q, variables:$v}' | gh api graphql --input -)"
  GT="$(jq -r '.data.addPullRequestReviewThread.thread.id' <<<"${RES}")"
  GC="$(jq -r '.data.addPullRequestReviewThread.thread.comments.nodes[0].id' <<<"${RES}")"
  [ "${GT}" != "null" ] || { echo "error: ${TID} の投稿に失敗しました: ${RES}" >&2; exit 1; }

  EXISTING="$(python3 "${STATE_PY}" latest --state "${STATE_FILE}" | jq -c --arg id "${TID}" '.[] | select(.difit_thread_id == $id)')"
  if [ -n "${EXISTING}" ]; then
    KEY="$(jq -r '.key' <<<"${EXISTING}")"
    python3 "${STATE_PY}" set-status --state "${STATE_FILE}" --difit-id "${TID}" --status posted \
      --github-thread-id "${GT}" --github-comment-id "${GC}" >/dev/null
  else
    KEY="${TID}"
    LINE_JSON="$(jq -c '.position.line' <<<"${THREAD}")"
    SIDE_LC="$(jq -r '.position.side' <<<"${THREAD}")"
    ROOT_BODY="$(jq -r '.messages[0].body' <<<"${THREAD}")"
    jq -n --arg file "${FILE}" --arg side "${SIDE_LC}" --argjson line "${LINE_JSON}" --arg summary "$(printf '%s' "${ROOT_BODY}" | head -1 | cut -c1-200)" \
      '{findings:[{file:$file, side:$side, line:$line, summary:$summary, perspective:null}]}' \
      | python3 "${STATE_PY}" enrich --worktree "${WORKTREE}" --base-sha "${BASE_SHA}" \
      | jq -c --arg key "${KEY}" --arg repo "${REPO}" --argjson pr "${PR}" --arg head "${HEAD_SHA}" --arg body "${BODY}" \
          --arg tid "${TID}" --arg gt "${GT}" --arg gc "${GC}" --arg now "$(date +%Y-%m-%dT%H:%M:%S%z)" \
          '.findings[0] | {schema_version:1, key:$key, repo:$repo, pr:$pr, head_sha:$head, file, side, line, scope, snippet, snippet_sha256,
            perspective:null, summary, body:$body, reason:null, fingerprint, origin:"user", difit_thread_id:$tid,
            github_thread_id:$gt, github_comment_id:$gc, status:"posted", created_at:$now, updated_at:$now}' \
      | python3 "${STATE_PY}" append --state "${STATE_FILE}"
  fi
  RESULTS="$(jq -c --arg tid "${TID}" --arg key "${KEY}" --arg gt "${GT}" --arg gc "${GC}" \
    '. + [{difit_thread_id:$tid, key:$key, github_thread_id:$gt, github_comment_id:$gc}]' <<<"${RESULTS}")"
done
jq . <<<"${RESULTS}"

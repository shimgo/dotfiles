#!/usr/bin/env bash
# PR の reviewThreads を全ページ取得する。
#
# 使い方: github-fetch-threads.sh <owner/repo> <PR 番号>
# 出力: {"pull_request_id": ..., "viewer_login": ..., "viewer_pending_review_id": ..., "threads": [...]}

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh jq

REPO="$1"; PR="$2"
OWNER="${REPO%%/*}"; NAME="${REPO##*/}"

QUERY='
query($owner: String!, $repo: String!, $number: Int!, $endCursor: String) {
  viewer { login }
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      id
      reviews(first: 20, states: PENDING) { nodes { id author { login } } }
      reviewThreads(first: 100, after: $endCursor) {
        nodes {
          id isResolved isOutdated subjectType path diffSide startDiffSide
          line startLine originalLine originalStartLine
          comments(first: 100) { nodes { id databaseId body createdAt updatedAt url author { login } } }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}'

CURSOR=""
ALL='[]'
PR_ID=""
VIEWER=""
PENDING=""
while :; do
  if [ -n "${CURSOR}" ]; then
    PAGE="$(gh api graphql -f query="${QUERY}" -F owner="${OWNER}" -F repo="${NAME}" -F number="${PR}" -F endCursor="${CURSOR}")"
  else
    PAGE="$(gh api graphql -f query="${QUERY}" -F owner="${OWNER}" -F repo="${NAME}" -F number="${PR}")"
  fi
  PR_ID="$(jq -r '.data.repository.pullRequest.id' <<<"${PAGE}")"
  VIEWER="$(jq -r '.data.viewer.login' <<<"${PAGE}")"
  PENDING="$(jq -r --arg v "${VIEWER}" '[.data.repository.pullRequest.reviews.nodes[] | select(.author.login == $v) | .id][0] // empty' <<<"${PAGE}")"
  ALL="$(jq -c --argjson page "$(jq -c '.data.repository.pullRequest.reviewThreads.nodes' <<<"${PAGE}")" '. + $page' <<<"${ALL}")"
  if [ "$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage' <<<"${PAGE}")" != "true" ]; then
    break
  fi
  CURSOR="$(jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor' <<<"${PAGE}")"
done

jq -n --arg id "${PR_ID}" --arg viewer "${VIEWER}" --arg pending "${PENDING}" --argjson threads "${ALL}" \
  '{pull_request_id:$id, viewer_login:$viewer, viewer_pending_review_id:(if $pending == "" then null else $pending end), threads:$threads}'

#!/usr/bin/env bash
# ユーザーの指示で、difit 上のスレッドを別の指摘にまとめ直すために閉じる。置き換え先の指摘は、この後 difit-post.sh で投稿する。
#
# 使い方: difit-supersede.sh <状態ディレクトリ> --reason <理由> <difit_thread_id>...
#
# 対象にできるのは Claude の指摘とユーザー自身のスレッド (origin が claude / user) だけ。
# GitHub から取り込んだ他人のスレッドは、他人の発言を閉じることになるので対象にしない。
#
# 実施内容:
#   1. すべての対象を検証する。1 件でも条件を満たさなければ、何も変更せずに中断する
#      - 状態ファイルにレコードがあり、origin が claude / user で、status が superseded でないこと
#      - GitHub にコメントがあるなら、そのコメントが未送信の pending review のものであること
#        送信済みのコメントは PR 作者が読んでいるため、置き換えのために消さない
#   2. 未送信の pending コメントを削除する。削除の結果 pending review にコメントも本文も無くなれば、pending review も削除する
#      空の pending review を残すと、next.sh が「未送信の pending review がある」と判定し続ける
#   3. status を superseded にして理由を記録する。照合 (state.py match) と reconcile はこのレコードを対象にしない
#   4. difit のスレッドを resolve する。resolve はスレッドの削除なので、記録を先に残す
#
# 出力: {"superseded": [...], "deleted_pending_comments": [...], "deleted_pending_reviews": [...]}

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh jq difit python3 curl

STATE_ARG=""
REASON=""
IDS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --reason) REASON="$2"; shift ;;
    -*) echo "error: 不明なオプション: $1" >&2; exit 1 ;;
    *) if [ -z "${STATE_ARG}" ]; then STATE_ARG="$1"; else IDS+=("$1"); fi ;;
  esac
  shift
done
[ -n "${STATE_ARG}" ] && [ -n "${REASON}" ] && [ "${#IDS[@]}" -gt 0 ] \
  || { echo "usage: difit-supersede.sh <state-dir> --reason <理由> <difit_thread_id>..." >&2; exit 1; }
load_session "${STATE_ARG}"
difit_alive || { echo "error: difit (port ${DIFIT_PORT}) に接続できません" >&2; exit 1; }

LATEST="$(python3 "${STATE_PY}" latest --state "${STATE_FILE}")"

# 1. 検証
DELETE_COMMENTS=()
KEYS=()
for TID in "${IDS[@]}"; do
  REC="$(jq -c --arg id "${TID}" '[.[] | select(.difit_thread_id == $id or .key == $id)][0] // empty' <<<"${LATEST}")"
  [ -n "${REC}" ] || { echo "error: ${TID} のレコードが状態ファイルにありません。何も変更していません" >&2; exit 1; }
  KEYS+=("$(jq -r '.key' <<<"${REC}")")
  ORIGIN="$(jq -r '.origin' <<<"${REC}")"
  case "${ORIGIN}" in
    claude|user) ;;
    *) echo "error: ${TID} は origin が ${ORIGIN} のスレッドです。他人のスレッドは付け直しの対象にできません。何も変更していません" >&2; exit 1 ;;
  esac
  [ "$(jq -r '.status' <<<"${REC}")" != "superseded" ] \
    || { echo "error: ${TID} は既に superseded です。何も変更していません" >&2; exit 1; }
  GC="$(jq -r '.github_comment_id // empty' <<<"${REC}")"
  [ -n "${GC}" ] || continue
  STATE="$(gh api graphql -F id="${GC}" -f query='
query($id: ID!) { node(id: $id) { ... on PullRequestReviewComment { state } } }' --jq '.data.node.state // empty')"
  case "${STATE}" in
    PENDING) DELETE_COMMENTS+=("${GC}") ;;
    "") ;; # GitHub から既に消えている。削除するものは無い
    *) echo "error: ${TID} の GitHub のコメント ${GC} は送信済み (${STATE}) です。送信済みのコメントは付け直せません。何も変更していません" >&2; exit 1 ;;
  esac
done

# 2. 未送信の pending コメントの削除
DELETED_REVIEWS='[]'
REVIEW_IDS=()
for GC in "${DELETE_COMMENTS[@]+"${DELETE_COMMENTS[@]}"}"; do
  RID="$(gh api graphql -F id="${GC}" -f query='
mutation($id: ID!) { deletePullRequestReviewComment(input: {id: $id}) { pullRequestReview { id } } }' \
    --jq '.data.deletePullRequestReviewComment.pullRequestReview.id')"
  REVIEW_IDS+=("${RID}")
done
for RID in $(printf '%s\n' "${REVIEW_IDS[@]+"${REVIEW_IDS[@]}"}" | sort -u); do
  REVIEW="$(gh api graphql -F id="${RID}" -f query='
query($id: ID!) { node(id: $id) { ... on PullRequestReview { state body comments { totalCount } } } }' --jq '.data.node')"
  if [ "$(jq -r '.state' <<<"${REVIEW}")" = "PENDING" ] && [ "$(jq -r '.comments.totalCount' <<<"${REVIEW}")" -eq 0 ] \
    && [ -z "$(jq -r '.body // "" | gsub("\\s"; "")' <<<"${REVIEW}")" ]; then
    gh api graphql -F id="${RID}" -f query='
mutation($id: ID!) { deletePullRequestReview(input: {pullRequestReviewId: $id}) { pullRequestReview { id } } }' >/dev/null
    DELETED_REVIEWS="$(jq -c --arg id "${RID}" '. + [$id]' <<<"${DELETED_REVIEWS}")"
  fi
done

# 3. 記録 → 4. difit から消す
for KEY in "${KEYS[@]}"; do
  python3 "${STATE_PY}" set-status --state "${STATE_FILE}" --key "${KEY}" --status superseded --reason "${REASON}" >/dev/null
done
difit comment resolve "${IDS[@]}" --port "${DIFIT_PORT}" >&2 \
  || echo "warning: difit に見つからないスレッドがありました (状態ファイルには superseded を記録済み)" >&2

jq -n --args '$ARGS.positional' "${IDS[@]}" \
  | jq -c --argjson reviews "${DELETED_REVIEWS}" --args '{superseded: ., deleted_pending_comments: $ARGS.positional, deleted_pending_reviews: $reviews}' \
    "${DELETE_COMMENTS[@]+"${DELETE_COMMENTS[@]}"}"

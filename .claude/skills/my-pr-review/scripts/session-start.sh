#!/usr/bin/env bash
# レビューセッションを開始する。
#
# 使い方:
#   session-start.sh <PR の URL または番号> [--local] [--review-skill <スキル名>]
#
# --local を付けると、現在のチェックアウトをそのまま使う (自分の PR のセルフレビュー)。
# 付けなければ PR の head を fetch し、リポジトリの隣に <repo>-pr-<番号> という worktree を作る。
#
# 実施内容:
#   1. PR 情報の取得と worktree の準備
#   2. difit をバックグラウンドで起動
#   3. GitHub 上の未解決スレッドを difit に取り込み、状態ファイルに記録
#   4. 前回のセッションが残っていれば、GitHub 未投稿の open なスレッドを再投入
#   5. session.json の書き出し
#
# 同じ PR の difit が動いている間は実行を拒否する (head の更新は sync.sh が担当)。
#
# 出力: session.json の内容 (JSON)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh git jq difit python3 curl

PR_ARG=""
PREV_HEAD_SHA=""
MODE="worktree"
REVIEW_SKILL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --local) MODE="local" ;;
    --review-skill) REVIEW_SKILL="$2"; shift ;;
    -*) echo "error: 不明なオプション: $1" >&2; exit 1 ;;
    *) PR_ARG="$1" ;;
  esac
  shift
done
[ -n "${PR_ARG}" ] || { echo "usage: session-start.sh <pr-url|number> [--local] [--review-skill NAME]" >&2; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
PR_JSON="$(gh pr view "${PR_ARG}" --json number,url,headRefName,headRefOid,baseRefName,isCrossRepository)"
PR="$(jq -r '.number' <<<"${PR_JSON}")"
PR_URL="$(jq -r '.url' <<<"${PR_JSON}")"
HEAD_REF="$(jq -r '.headRefName' <<<"${PR_JSON}")"
HEAD_SHA="$(jq -r '.headRefOid' <<<"${PR_JSON}")"
BASE_REF="$(jq -r '.baseRefName' <<<"${PR_JSON}")"

STATE_DIR="$(state_dir_for "${REPO}" "${PR}")"
SESSION="${STATE_DIR}/session.json"
STATE_FILE="${STATE_DIR}/threads.jsonl"
mkdir -p "${STATE_DIR}"

if [ -f "${SESSION}" ]; then
  DIFIT_PORT="$(jq -r '.difit.port // empty' "${SESSION}")"
  if difit_alive; then
    echo "error: この PR のセッションは既に動いています (port ${DIFIT_PORT})。head を更新したいなら sync.sh を使ってください" >&2
    exit 1
  fi
  echo "info: 前回のセッションを引き継ぎます。未投稿の指摘は difit に再投入します" >&2
  PREV_HEAD_SHA="$(jq -r '.head_sha // empty' "${SESSION}")"
fi

git fetch --quiet origin "${BASE_REF}"
if [ "${MODE}" = "local" ]; then
  WORKTREE="${REPO_ROOT}"
  LOCAL_HEAD="$(git rev-parse HEAD)"
  if [ "${LOCAL_HEAD}" != "${HEAD_SHA}" ]; then
    echo "warning: ローカル HEAD (${LOCAL_HEAD:0:7}) が PR の head (${HEAD_SHA:0:7}) と異なります。ローカルを対象にします" >&2
    HEAD_SHA="${LOCAL_HEAD}"
  fi
else
  git fetch --quiet origin "refs/pull/${PR}/head"
  HEAD_SHA="$(git rev-parse FETCH_HEAD)"
  WORKTREE="$(dirname "${REPO_ROOT}")/$(basename "${REPO_ROOT}")-pr-${PR}"
  if [ -d "${WORKTREE}" ]; then
    echo "info: 既存の worktree ${WORKTREE} を ${HEAD_SHA:0:7} に更新します" >&2
    git -C "${WORKTREE}" checkout --quiet --detach "${HEAD_SHA}"
  else
    git worktree add --quiet --detach "${WORKTREE}" "${HEAD_SHA}"
  fi
fi
BASE_SHA="$(git -C "${WORKTREE}" merge-base "${HEAD_SHA}" "origin/${BASE_REF}")"

DIFIT_JSON="$(start_difit "${WORKTREE}" "${HEAD_SHA}" "${BASE_SHA}" "${MODE}" "${BASE_REF}")"
DIFIT_PORT="$(jq -r '.port' <<<"${DIFIT_JSON}")"
wait_difit_ready "${DIFIT_PORT}"

THREADS_JSON="$("${SCRIPT_DIR}/github-fetch-threads.sh" "${REPO}" "${PR}")"
CONVERTED="$(printf '%s' "${THREADS_JSON}" | python3 "${STATE_PY}" from-github \
  --state "${STATE_FILE}" --repo "${REPO}" --pr "${PR}" --head-sha "${HEAD_SHA}" \
  --worktree "${WORKTREE}" --base-sha "${BASE_SHA}")"
difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${CONVERTED}")"
jq -c '.records' <<<"${CONVERTED}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

# 前回のセッションで GitHub に投稿しないまま残っている open なスレッドを再投入する
REBUILT="$(python3 "${STATE_PY}" rebuild --state "${STATE_FILE}" --repo "${REPO}" --pr "${PR}" --head-sha "${HEAD_SHA}" \
  --worktree "${WORKTREE}" --base-sha "${BASE_SHA}" --snapshot "${STATE_DIR}/difit-last.json" --snapshot-head-sha "${PREV_HEAD_SHA}")"
difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${REBUILT}")"
jq -c '.records' <<<"${REBUILT}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

jq -n \
  --arg repo "${REPO}" --argjson pr "${PR}" --arg pr_url "${PR_URL}" --arg mode "${MODE}" \
  --arg worktree "${WORKTREE}" --arg base_ref "${BASE_REF}" --arg head_ref "${HEAD_REF}" \
  --arg base_sha "${BASE_SHA}" --arg head_sha "${HEAD_SHA}" --argjson difit "${DIFIT_JSON}" \
  --arg review_skill "${REVIEW_SKILL}" --arg now "$(date +%Y-%m-%dT%H:%M:%S%z)" \
  '{repo:$repo, pr:$pr, pr_url:$pr_url, mode:$mode, worktree:$worktree, base_ref:$base_ref, head_ref:$head_ref,
    base_sha:$base_sha, head_sha:$head_sha, reviewed_head_sha:null, last_phase:"start", difit:$difit,
    review_skill:(if $review_skill == "" then null else $review_skill end), started_at:$now, updated_at:$now,
    state_dir:($worktree|tostring|"")}' \
  | jq --arg d "${STATE_DIR}" '.state_dir = $d' > "${SESSION}"

cat "${SESSION}"

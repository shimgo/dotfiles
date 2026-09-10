#!/usr/bin/env bash
# GitHub の最新状態を状態ファイルに反映し、difit を最新の head で作り直す。
#
# 使い方: sync.sh <状態ディレクトリ> [--no-restart]
#
# 実施内容:
#   1. GitHub の reviewThreads を取得し、resolved / 削除されたスレッドの status を更新する
#   2. PR の head を取得し直す (worktree モードでは detach で checkout、local モードでは現在の HEAD を採用)
#   3. difit を停止し、新しい head と base で --clean 起動する (--no-restart で省略)
#      停止前のスレッドは difit-last.json に保存し、状態ファイルに無いユーザーのスレッドと返信を失わないようにする
#   4. GitHub の未解決スレッドと、ローカルで open なスレッドを difit に再投入する
#      ローカルのスレッドは snippet で位置を探し直し、見つからなければ status を outdated にする
#
# 出力 (JSON): status を変えたレコード、警告、再投入の内訳、更新後の session

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh git jq difit python3 curl
load_session "$1"
RESTART=true
[ "${2:-}" = "--no-restart" ] && RESTART=false

# 1. GitHub との突き合わせ
THREADS_JSON="$("${SCRIPT_DIR}/github-fetch-threads.sh" "${REPO}" "${PR}")"
RECONCILED="$(printf '%s' "${THREADS_JSON}" | python3 "${STATE_PY}" reconcile --state "${STATE_FILE}")"
jq -c '.records' <<<"${RECONCILED}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

# 2. head の更新
OLD_HEAD="${HEAD_SHA}"
git -C "${WORKTREE}" fetch --quiet origin "${BASE_REF}"
if [ "${MODE}" = "local" ]; then
  HEAD_SHA="$(git -C "${WORKTREE}" rev-parse HEAD)"
else
  git -C "${WORKTREE}" fetch --quiet origin "refs/pull/${PR}/head"
  HEAD_SHA="$(git -C "${WORKTREE}" rev-parse FETCH_HEAD)"
  if [ "${HEAD_SHA}" != "${OLD_HEAD}" ]; then
    git -C "${WORKTREE}" checkout --quiet --detach "${HEAD_SHA}"
  fi
fi
BASE_SHA="$(git -C "${WORKTREE}" merge-base "${HEAD_SHA}" "origin/${BASE_REF}")"
NOW="$(date +%Y-%m-%dT%H:%M:%S%z)"

if [ "${RESTART}" = false ]; then
  update_session ".head_sha = \"${HEAD_SHA}\" | .base_sha = \"${BASE_SHA}\" | .updated_at = \"${NOW}\""
  jq -n --argjson r "${RECONCILED}" --argjson s "$(cat "${SESSION}")" '{reconciled:$r.records, warnings:$r.warnings, session:$s}'
  exit 0
fi

# 3. difit の再起動
SNAPSHOT="${STATE_DIR}/difit-last.json"
if difit_alive; then
  difit comment get --port "${DIFIT_PORT}" --format json > "${SNAPSHOT}"
fi
stop_difit "${DIFIT_PID}"
DIFIT_JSON="$(start_difit "${WORKTREE}" "${HEAD_SHA}" "${BASE_SHA}" "${MODE}")"
DIFIT_PORT="$(jq -r '.port' <<<"${DIFIT_JSON}")"
# 以降の手順が失敗しても difit が迷子にならないよう、起動直後に session.json へ書く
update_session ".head_sha = \"${HEAD_SHA}\" | .base_sha = \"${BASE_SHA}\" | .difit = ${DIFIT_JSON} | .updated_at = \"${NOW}\""

# 4a. GitHub の未解決スレッド
CONVERTED="$(printf '%s' "${THREADS_JSON}" | python3 "${STATE_PY}" from-github \
  --state "${STATE_FILE}" --repo "${REPO}" --pr "${PR}" --head-sha "${HEAD_SHA}" --worktree "${WORKTREE}" --base-sha "${BASE_SHA}")"
difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${CONVERTED}")"
jq -c '.records' <<<"${CONVERTED}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

# 4b. GitHub 未投稿でローカルに open なスレッド (Claude の指摘と、ユーザーが difit 上で書いたもの)。返信も一緒に再投入する
REBUILT="$(python3 "${STATE_PY}" rebuild --state "${STATE_FILE}" --repo "${REPO}" --pr "${PR}" --head-sha "${HEAD_SHA}" \
  --worktree "${WORKTREE}" --base-sha "${BASE_SHA}" --snapshot "${SNAPSHOT}" --snapshot-head-sha "${OLD_HEAD}")"
difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${REBUILT}")"
jq -c '.records' <<<"${REBUILT}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

jq -n --argjson r "${RECONCILED}" --argjson rb "${REBUILT}" --argjson c "${CONVERTED}" --argjson s "$(cat "${SESSION}")" '{
  reconciled: $r.records, warnings: $r.warnings,
  reimported: {github: ($c.imports | map(select(.type == "thread")) | length),
               local: ($rb.imports | map(select(.type == "thread")) | length),
               outdated: $rb.outdated},
  session: $s }'

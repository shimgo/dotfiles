#!/usr/bin/env bash
# GitHub の最新状態を状態ファイルに反映し、difit を最新の head で作り直す。
#
# 使い方: sync.sh <状態ディレクトリ> [--no-restart] [--allow-empty-snapshot]
#
# 実施内容:
#   1. GitHub の reviewThreads を取得し、resolved / 削除されたスレッドの status を更新する
#   2. PR の head を取得し直す (worktree モードでは detach で checkout、local モードでは現在の HEAD を採用)
#   3. difit を停止し、新しい head と base で --clean 起動して URL を標準エラーへ出す (--no-restart で省略)
#      停止前のスレッドは difit-last.json に保存し、状態ファイルに無いユーザーのスレッドと返信を失わないようにする
#   4. GitHub の未解決スレッドと、ローカルで open なスレッドを difit に再投入する
#      ローカルのスレッドは snippet で位置を探し直し、見つからなければ status を outdated にする
#
# 出力 (JSON): status を変えたレコード、警告、再投入の内訳、更新後の session

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh git jq difit python3 curl
load_session "$1"
shift
RESTART=true
ALLOW_EMPTY_SNAPSHOT=false
while [ $# -gt 0 ]; do
  case "$1" in
    --no-restart) RESTART=false ;;
    --allow-empty-snapshot) ALLOW_EMPTY_SNAPSHOT=true ;;
    *) echo "error: 不明なオプション: $1" >&2; exit 1 ;;
  esac
  shift
done

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
  # 対応要否の判断 (返信) は difit にしか無く、状態ファイルには triage を通すまで残らない。
  # スナップショットが空なのに再投入する open なスレッドがあるなら、取得に失敗した可能性が高い。
  # そのまま作り直すと返信を失うため中断する。
  SNAPSHOT_THREADS="$(jq '.threads | length' "${SNAPSHOT}" 2>/dev/null || echo 0)"
  OPEN_THREADS="$(python3 "${STATE_PY}" latest --state "${STATE_FILE}" | jq '[.[] | select(.status == "open")] | length')"
  if [ "${SNAPSHOT_THREADS}" -eq 0 ] && [ "${OPEN_THREADS}" -gt 0 ] && [ "${ALLOW_EMPTY_SNAPSHOT}" = false ]; then
    echo "error: difit は動いていますがスレッドを 0 件しか取得できませんでした (open なスレッドは ${OPEN_THREADS} 件)。" >&2
    echo "       このまま作り直すと difit 上の返信 (対応要否の判断) を失います。" >&2
    echo "       difit comment get --port ${DIFIT_PORT} --format json を手で確認してください。" >&2
    echo "       返信を失ってよいと判断したら --allow-empty-snapshot を付けて再実行してください。" >&2
    exit 1
  fi
fi
stop_difit "${DIFIT_PID}"
DIFIT_JSON="$(start_difit "${WORKTREE}" "${HEAD_SHA}" "${BASE_SHA}" "${MODE}" "${BASE_REF}")"
DIFIT_PORT="$(jq -r '.port' <<<"${DIFIT_JSON}")"
# 以降の手順が失敗しても difit が迷子にならないよう、起動直後に session.json へ書く
update_session ".head_sha = \"${HEAD_SHA}\" | .base_sha = \"${BASE_SHA}\" | .difit = ${DIFIT_JSON} | .updated_at = \"${NOW}\""
wait_difit_ready "${DIFIT_PORT}"
announce_difit_url "$(jq -r '.url' <<<"${DIFIT_JSON}")"

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

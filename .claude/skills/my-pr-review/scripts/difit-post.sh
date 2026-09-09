#!/usr/bin/env bash
# レビュースキルの指摘 (findings JSON) を照合し、difit に投稿して状態ファイルに記録する。
#
# 使い方: difit-post.sh <状態ディレクトリ> <findings.json>
# findings.json の形式は reference/findings.schema.json を参照。
#
# 出力 (JSON):
#   suppressed: 抑止した指摘 (過去の判断と prior を含む)
#   annotated:  過去の判断を注記して投稿した指摘
#   posted:     投稿した件数

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need jq difit python3 curl
load_session "$1"
FINDINGS="$2"
[ -f "${FINDINGS}" ] || { echo "error: ${FINDINGS} がありません" >&2; exit 1; }
difit_alive || { echo "error: difit (port ${DIFIT_PORT}) に接続できません。sync.sh で再起動してください" >&2; exit 1; }

DECIDED="$(python3 "${STATE_PY}" enrich --worktree "${WORKTREE}" --base-sha "${BASE_SHA}" < "${FINDINGS}" \
  | python3 "${STATE_PY}" match --state "${STATE_FILE}")"
CONVERTED="$(printf '%s' "${DECIDED}" | python3 "${STATE_PY}" to-difit --repo "${REPO}" --pr "${PR}" --head-sha "${HEAD_SHA}")"

difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${CONVERTED}")"
jq -c '.records' <<<"${CONVERTED}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

jq -n --argjson d "${DECIDED}" --argjson c "${CONVERTED}" '{
  suppressed: [$d.findings[] | select(.decision == "suppress") | {file, line, perspective, summary, prior: {status: .prior.status, summary: .prior.summary, reason: .prior.reason}}],
  annotated:  [$d.findings[] | select(.decision == "annotate") | {file, line, perspective, summary, prior: {status: .prior.status, summary: .prior.summary, reason: .prior.reason}}],
  posted: ($c.imports | length)
}'

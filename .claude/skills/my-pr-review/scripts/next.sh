#!/usr/bin/env bash
# 次に実行すべきフェーズを判定する。
#
# 使い方: next.sh <状態ディレクトリ>
# 出力 (JSON): {"phase": "...", "reason": "...", "mode": "...", "last_phase": "...", "difit": {分類ごとの件数}}
#
# 判定の優先順位:
#   1. difit に未回答の質問があれば answer
#   2. difit に未処理の返信 (fix / dismiss / user_finding / unclear) があれば triage
#   3. それ以外は直前のフェーズから決める
#        start / なし → review
#        review / answer → wait (ユーザーが difit で対応要否を付けるのを待つ)
#        triage (worktree) → sync。ただし pending review が未送信なら wait
#        triage (local) → review (差分の再レビュー)
#        sync → verify (posted / outdated があれば)、無ければ review
#        verify → review

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need jq python3 difit curl gh
load_session "$1"
LAST="$(jq -r '.last_phase // "start"' "${SESSION}")"

COUNTS='{}'
if difit_alive; then
  COUNTS="$("${SCRIPT_DIR}/difit-fetch.sh" "${STATE_DIR}" | jq -c '[.threads[].classification] | group_by(.) | map({(.[0]): length}) | add // {}')"
else
  jq -n --arg last "${LAST}" --arg mode "${MODE}" '{phase:"sync", reason:"difit が停止しているため作り直す", mode:$mode, last_phase:$last, difit:{}}'
  exit 0
fi
count() { jq -r --arg k "$1" '.[$k] // 0' <<<"${COUNTS}"; }

emit() {
  jq -n --arg phase "$1" --arg reason "$2" --arg last "${LAST}" --arg mode "${MODE}" --argjson difit "${COUNTS}" \
    '{phase:$phase, reason:$reason, mode:$mode, last_phase:$last, difit:$difit}'
  exit 0
}

[ "$(count question)" -gt 0 ] && emit answer "未回答の質問が $(count question) 件ある"
PENDING_REPLIES=$(( $(count fix) + $(count dismiss) + $(count user_finding) + $(count unclear) ))
[ "${PENDING_REPLIES}" -gt 0 ] && emit triage "未処理の返信が ${PENDING_REPLIES} 件ある"

case "${LAST}" in
  start) emit review "セッション開始直後でまだレビューしていない" ;;
  review|answer) emit wait "difit で対応要否 (+ / -) が付くのを待つ。返信が無い Claude の指摘: $(count pending) 件" ;;
  triage)
    if [ "${MODE}" = "local" ]; then
      emit review "実装した差分を再レビューする"
    fi
    PENDING_ID="$("${SCRIPT_DIR}/github-fetch-threads.sh" "${REPO}" "${PR}" | jq -r '.viewer_pending_review_id // empty')"
    if [ -n "${PENDING_ID}" ]; then
      emit wait "GitHub に未送信の pending review がある。送信後に sync する"
    fi
    emit sync "GitHub のレビュー状態を取り込み difit を作り直す"
    ;;
  sync)
    N="$(python3 "${STATE_PY}" latest --state "${STATE_FILE}" --status posted --status outdated | jq 'length')"
    if [ "${N}" -gt 0 ]; then
      emit verify "修正を確認する指摘が ${N} 件ある"
    fi
    emit review "確認待ちの指摘は無いので再レビューする"
    ;;
  verify) emit review "修正差分を再レビューする" ;;
  *) emit wait "判定できない (last_phase=${LAST})" ;;
esac

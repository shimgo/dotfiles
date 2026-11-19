#!/usr/bin/env bash
# 次に実行すべきフェーズを判定する。
#
# 使い方: next.sh <状態ディレクトリ>
# 出力 (JSON): {"phase": "...", "reason": "...", "mode": "...", "last_phase": "...", "difit": {分類ごとの件数}}
#
# 判定の優先順位:
#   1. sync が位置を特定できずに difit から外した、ユーザーの発言を含むスレッドがあれば restore
#      ユーザーの発言は difit に戻すまで見えないため、answer や triage より先に戻す
#   2. difit に未処理の Claude Code 宛ての本文 ("q ...") があれば answer
#   3. difit に未処理の返信 (fix / dismiss / user_finding) があれば triage
#      GitHub への投稿などで処理済みのスレッドは processed に分類するので数えない
#   4. local モードで reviewed_head_sha 以降にコミットを積んでいれば review (先に sync.sh で difit と session.json の head を合わせる)
#      answer / triage で実装したコミットと、review の後にスキルの外で積んだコミットを再レビューするため。
#      review は reviewed_head_sha を head_sha (local モードでは git の HEAD) に揃えるので、レビュー直後には一致し、review を繰り返さない
#   5. それ以外は直前のフェーズから決める
#        start / なし → review
#        review / answer → wait (ユーザーが difit で対応要否を付けるのを待つ)
#        triage (github) → sync。ただし次のときは wait
#          - pending review が未送信 (ユーザーが GitHub で送信するのを待つ)
#          - 返信待ちの Claude の指摘 (pending / none) が残っている (作り直すとポートが変わり、ユーザーが開いている difit を失う)
#          - GitHub に投稿した指摘 (posted) が無く、PR の head も変わっていない (取り込むものが無い)
#        triage (local) → review (差分の再レビュー)
#        sync / restore → verify (posted / outdated があれば)、無ければ review
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

RESTORE_N="$(python3 "${STATE_PY}" latest --state "${STATE_FILE}" --needs-restore | jq 'length')"
[ "${RESTORE_N}" -gt 0 ] && emit restore "sync が位置を特定できずに difit から外した、ユーザーの発言を含むスレッドが ${RESTORE_N} 件ある"
[ "$(count to_claude)" -gt 0 ] && emit answer "未処理の Claude Code 宛ての本文が $(count to_claude) 件ある"
PENDING_REPLIES=$(( $(count fix) + $(count dismiss) + $(count user_finding) ))
[ "${PENDING_REPLIES}" -gt 0 ] && emit triage "未処理の返信が ${PENDING_REPLIES} 件ある"

if [ "${MODE}" = "local" ] && [ -n "${REVIEWED_HEAD_SHA}" ]; then
  CURRENT_HEAD="$(git -C "${WORKTREE}" rev-parse HEAD)"
  if [ "${CURRENT_HEAD}" != "${REVIEWED_HEAD_SHA}" ]; then
    emit review "reviewed_head_sha 以降にコミットを積んでいる。sync.sh で difit を作り直してから差分を再レビューする"
  fi
fi

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
    AWAITING=$(( $(count pending) + $(count none) ))
    if [ "${AWAITING}" -gt 0 ]; then
      emit wait "difit で対応要否 (+ / -) が付くのを待つ。返信を待っているスレッド: ${AWAITING} 件"
    fi
    POSTED_N="$(python3 "${STATE_PY}" latest --state "${STATE_FILE}" --status posted | jq 'length')"
    REMOTE_HEAD="$(gh pr view "${PR}" --repo "${REPO}" --json headRefOid -q .headRefOid)"
    if [ "${POSTED_N}" -eq 0 ] && [ "${REMOTE_HEAD}" = "${HEAD_SHA}" ]; then
      emit wait "GitHub に投稿した指摘が無く、PR の head も変わっていない。PR 作者の更新を待つ"
    fi
    emit sync "GitHub のレビュー状態を取り込み difit を作り直す"
    ;;
  sync|restore)
    N="$(python3 "${STATE_PY}" latest --state "${STATE_FILE}" --status posted --status outdated | jq 'length')"
    if [ "${N}" -gt 0 ]; then
      emit verify "修正を確認する指摘が ${N} 件ある"
    fi
    emit review "確認待ちの指摘は無いので再レビューする"
    ;;
  verify) emit review "修正差分を再レビューする" ;;
  *) emit wait "判定できない (last_phase=${LAST})" ;;
esac

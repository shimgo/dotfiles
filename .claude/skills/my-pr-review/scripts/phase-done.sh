#!/usr/bin/env bash
# フェーズの完了を session.json に記録する。next.sh が次の工程を判定するのに使う。
#
# 使い方: phase-done.sh <状態ディレクトリ> <start|review|answer|triage|sync|verify>

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need jq
load_session "$1"
PHASE="$2"
case "${PHASE}" in
  start|review|answer|triage|sync|verify) ;;
  *) echo "error: 不明なフェーズ: ${PHASE}" >&2; exit 1 ;;
esac
update_session ".last_phase = \"${PHASE}\" | .updated_at = \"$(date +%Y-%m-%dT%H:%M:%S%z)\""
jq -c '{last_phase, updated_at}' "${SESSION}"

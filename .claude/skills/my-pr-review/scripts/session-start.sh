#!/usr/bin/env bash
# レビューセッションを開始する。
#
# 使い方:
#   session-start.sh [<PR の URL または番号>] [--base <ブランチ>] [--review-skill <スキル名>]
#
# レビュー対象は常に現在のチェックアウトであり、PR があるときに現在のブランチが PR のブランチでなければ中断する。
# PR を省略すると現在のブランチの open な PR を使い、無ければ PR を作る前のセルフレビューとして local モードで開始する。
# モードは PR の作者から決める。
#   local:  PR の作者が gh のログイン中のアカウント (自分の PR のセルフレビュー。ケース 2)、または PR が無い。
#           指摘への対応を現在のブランチへコミットする
#   github: それ以外 (ケース 1)。指摘を GitHub の pending review に投稿し、コミットしない。
#           HEAD が PR の head と一致し、未コミットの変更が無いことを求める
#
# --base は PR が無いときの base ブランチ。省略すると前回のセッションの base、それも無ければリポジトリのデフォルトブランチを使う。
# PR があるときは PR の base を使い、--base を無視する。
#
# 状態ディレクトリは PR があれば pr-<番号>、無ければ branch-<ブランチ名> である (common.sh)。
# local モードで pr-<番号> が無く、同じブランチの branch-<ブランチ名> があれば、PR を作る前の判断を引き継ぐため pr-<番号> へ移す。
#
# 実施内容:
#   1. PR 情報の取得と現在のチェックアウトの検証
#   2. difit をバックグラウンドで起動し、応答を待って session.json を書き出す
#   3. difit の URL を標準エラーへ出す (以降の取り込みを待たずにユーザーがレビューを始められるようにする)
#   4. GitHub 上の未解決スレッドを difit に取り込み、状態ファイルに記録 (PR が無ければ省略)
#   5. 前回のセッションが残っていれば、GitHub 未投稿の open なスレッドを再投入
#
# 同じセッションの difit が動いている間は実行を拒否する (head の更新は sync.sh が担当)。
#
# 出力: session.json の内容 (JSON)

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
need gh git jq difit python3 curl

PR_ARG=""
BASE_OPT=""
PREV_HEAD_SHA=""
REVIEW_SKILL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE_OPT="$2"; shift ;;
    --review-skill) REVIEW_SKILL="$2"; shift ;;
    -*) echo "error: 不明なオプション: $1" >&2; exit 1 ;;
    *) PR_ARG="$1" ;;
  esac
  shift
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
CURRENT_BRANCH="$(git branch --show-current)"

# PR が指定されていなければ、現在のブランチの open な PR を探す。
# 見つからないことと gh の失敗 (認証切れ、ネットワーク) を区別し、失敗したときに PR なしで始めない。
if [ -z "${PR_ARG}" ]; then
  [ -n "${CURRENT_BRANCH}" ] || { echo "error: detached HEAD です。レビューするブランチを checkout してから実行してください" >&2; exit 1; }
  LOOKUP_ERR="$(mktemp)"
  if FOUND="$(gh pr view --json number,state 2>"${LOOKUP_ERR}")"; then
    if [ "$(jq -r '.state' <<<"${FOUND}")" = "OPEN" ]; then
      PR_ARG="$(jq -r '.number' <<<"${FOUND}")"
    else
      echo "info: 現在のブランチの PR #$(jq -r '.number' <<<"${FOUND}") は $(jq -r '.state' <<<"${FOUND}") なので使いません" >&2
    fi
  elif ! grep -q 'no pull requests found' "${LOOKUP_ERR}"; then
    cat "${LOOKUP_ERR}" >&2
    rm -f "${LOOKUP_ERR}"
    exit 1
  fi
  rm -f "${LOOKUP_ERR}"
fi

if [ -n "${PR_ARG}" ]; then
  PR_JSON="$(gh pr view "${PR_ARG}" --json number,url,headRefName,headRefOid,baseRefName,isCrossRepository,author)"
  PR="$(jq -r '.number' <<<"${PR_JSON}")"
  PR_URL="$(jq -r '.url' <<<"${PR_JSON}")"
  HEAD_REF="$(jq -r '.headRefName' <<<"${PR_JSON}")"
  HEAD_SHA="$(jq -r '.headRefOid' <<<"${PR_JSON}")"
  BASE_REF="$(jq -r '.baseRefName' <<<"${PR_JSON}")"
  if [ -n "${BASE_OPT}" ] && [ "${BASE_OPT}" != "${BASE_REF}" ]; then
    echo "warning: PR があるため --base ${BASE_OPT} を無視し、PR の base (${BASE_REF}) を使います" >&2
  fi

  # モードを Claude の判断に任せない。local モードでは Claude が現在のブランチへ実装をコミットするため、
  # 他人の PR を local モードで開くと、他人のブランチに変更を加えることになる。
  PR_AUTHOR="$(jq -r '.author.login' <<<"${PR_JSON}")"
  VIEWER="$(gh api user -q .login)"
  if [ "${CURRENT_BRANCH}" != "${HEAD_REF}" ]; then
    echo "error: 現在のブランチ (${CURRENT_BRANCH:-(detached)}) が PR のブランチ (${HEAD_REF}) ではありません。gh pr checkout ${PR_ARG} で切り替えてから実行してください" >&2
    exit 1
  fi
  if [ "${PR_AUTHOR}" = "${VIEWER}" ]; then
    MODE="local"
  else
    MODE="github"
  fi
  echo "info: ${MODE} モードで開始します (PR の作者: ${PR_AUTHOR}, gh のログイン: ${VIEWER}, 現在のブランチ: ${CURRENT_BRANCH:-(detached)}, PR のブランチ: ${HEAD_REF})" >&2

  STATE_DIR="$(state_dir_for "${REPO}" "${PR}")"
  # PR を作る前のセルフレビューの判断 (対応不要にした指摘、指示で実装した変更) を PR のセッションへ引き継ぐ。
  # 他人の PR (github モード) では、同じ名前のブランチで行った自分のセッションを取り違えるおそれがあるので引き継がない。
  BRANCH_STATE_DIR="$(branch_state_dir_for "${REPO}" "${HEAD_REF}")"
  if [ "${MODE}" = "local" ] && [ ! -f "${STATE_DIR}/session.json" ] && [ -f "${BRANCH_STATE_DIR}/session.json" ]; then
    # 前回の実行が session.json を書く前に中断すると、空の状態ディレクトリが残る。mv がその中へ移さないよう先に消す
    if [ -d "${STATE_DIR}" ]; then
      rmdir "${STATE_DIR}" 2>/dev/null \
        || { echo "error: ${STATE_DIR} は session.json が無いのに空ではないため、${BRANCH_STATE_DIR} を引き継げません。中身を確認してください" >&2; exit 1; }
    fi
    mkdir -p "$(dirname "${STATE_DIR}")"
    mv "${BRANCH_STATE_DIR}" "${STATE_DIR}"
    # difit が動いていると、この後の確認で中断して sync.sh に任せる。sync.sh が PR と base を使えるよう、ここで session.json を更新する
    TMP_SESSION="$(mktemp)"
    jq --argjson pr "${PR}" --arg pr_url "${PR_URL}" --arg base_ref "${BASE_REF}" --arg d "${STATE_DIR}" \
      '.pr = $pr | .pr_url = $pr_url | .base_ref = $base_ref | .state_dir = $d' "${STATE_DIR}/session.json" > "${TMP_SESSION}"
    mv "${TMP_SESSION}" "${STATE_DIR}/session.json"
    echo "info: PR を作る前のセッション ${BRANCH_STATE_DIR} を ${STATE_DIR} に引き継ぎました" >&2
  fi
else
  # PR を作る前のセルフレビュー。作者を確かめられないので、自分のブランチとして local モードで扱う
  PR=""
  PR_URL=""
  HEAD_REF="${CURRENT_BRANCH}"
  HEAD_SHA=""
  MODE="local"
  STATE_DIR="$(branch_state_dir_for "${REPO}" "${HEAD_REF}")"
  BASE_REF="${BASE_OPT}"
  if [ -z "${BASE_REF}" ] && [ -f "${STATE_DIR}/session.json" ]; then
    BASE_REF="$(jq -r '.base_ref // empty' "${STATE_DIR}/session.json")"
  fi
  if [ -z "${BASE_REF}" ]; then
    BASE_REF="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)"
  fi
  echo "info: local モードで開始します (PR なし, 現在のブランチ: ${HEAD_REF}, base: ${BASE_REF})" >&2
fi

SESSION="${STATE_DIR}/session.json"
STATE_FILE="${STATE_DIR}/threads.jsonl"
mkdir -p "${STATE_DIR}"

if [ -f "${SESSION}" ]; then
  DIFIT_PORT="$(jq -r '.difit.port // empty' "${SESSION}")"
  if difit_alive; then
    echo "error: このセッションは既に動いています (port ${DIFIT_PORT})。head を更新したいなら sync.sh ${STATE_DIR} を使ってください" >&2
    exit 1
  fi
  echo "info: 前回のセッションを引き継ぎます。未投稿の指摘は difit に再投入します" >&2
  PREV_HEAD_SHA="$(jq -r '.head_sha // empty' "${SESSION}")"
fi

git fetch --quiet origin "${BASE_REF}"
WORKTREE="${REPO_ROOT}"
LOCAL_HEAD="$(git rev-parse HEAD)"
if [ "${MODE}" = "local" ]; then
  if [ -n "${HEAD_SHA}" ] && [ "${LOCAL_HEAD}" != "${HEAD_SHA}" ]; then
    echo "warning: ローカル HEAD (${LOCAL_HEAD:0:7}) が PR の head (${HEAD_SHA:0:7}) と異なります。ローカルを対象にします" >&2
  fi
  HEAD_SHA="${LOCAL_HEAD}"
else
  # github モードの difit は head と base の SHA の差分を表示するが、レビュースキルは作業ツリーのファイルを読む。
  # 両者が食い違うと、GitHub の PR に無いコードへ指摘を付けることになるため、作業ツリーが PR の head そのものであることを求める。
  git fetch --quiet origin "refs/pull/${PR}/head"
  HEAD_SHA="$(git rev-parse FETCH_HEAD)"
  if [ "${LOCAL_HEAD}" != "${HEAD_SHA}" ]; then
    echo "error: ローカル HEAD (${LOCAL_HEAD:0:7}) が PR の head (${HEAD_SHA:0:7}) と異なります。git pull --ff-only で揃えてから実行してください" >&2
    exit 1
  fi
  if [ -n "$(git status --porcelain)" ]; then
    echo "error: 未コミットの変更があります。他人の PR のレビューでは作業ツリーを PR の head と一致させる必要があるため、変更を退避してから実行してください" >&2
    exit 1
  fi
fi
BASE_SHA="$(git -C "${WORKTREE}" merge-base "${HEAD_SHA}" "origin/${BASE_REF}")"

DIFIT_JSON="$(start_difit "${WORKTREE}" "${HEAD_SHA}" "${BASE_SHA}" "${MODE}" "${BASE_REF}")"
DIFIT_PORT="$(jq -r '.port' <<<"${DIFIT_JSON}")"
wait_difit_ready "${DIFIT_PORT}"

# GitHub の取り込みより先に session.json を書き、URL を知らせる。
# ユーザーは取り込みの完了を待たずに差分を読み始められる。以降の手順が失敗しても difit が迷子にならない。
jq -n \
  --arg repo "${REPO}" --arg pr "${PR}" --arg pr_url "${PR_URL}" --arg mode "${MODE}" \
  --arg worktree "${WORKTREE}" --arg base_ref "${BASE_REF}" --arg head_ref "${HEAD_REF}" \
  --arg base_sha "${BASE_SHA}" --arg head_sha "${HEAD_SHA}" --argjson difit "${DIFIT_JSON}" \
  --arg review_skill "${REVIEW_SKILL}" --arg now "$(date +%Y-%m-%dT%H:%M:%S%z)" \
  '{repo:$repo, pr:(if $pr == "" then null else ($pr | tonumber) end), pr_url:(if $pr_url == "" then null else $pr_url end), mode:$mode, worktree:$worktree, base_ref:$base_ref, head_ref:$head_ref,
    base_sha:$base_sha, head_sha:$head_sha, reviewed_head_sha:null, last_phase:"start", difit:$difit,
    review_skill:(if $review_skill == "" then null else $review_skill end), started_at:$now, updated_at:$now,
    state_dir:($worktree|tostring|"")}' \
  | jq --arg d "${STATE_DIR}" '.state_dir = $d' > "${SESSION}"
announce_difit_url "$(jq -r '.url' <<<"${DIFIT_JSON}")"

if [ -n "${PR}" ]; then
  THREADS_JSON="$("${SCRIPT_DIR}/github-fetch-threads.sh" "${REPO}" "${PR}")"
  CONVERTED="$(printf '%s' "${THREADS_JSON}" | python3 "${STATE_PY}" from-github \
    --state "${STATE_FILE}" --repo "${REPO}" --pr "${PR}" --head-sha "${HEAD_SHA}" \
    --worktree "${WORKTREE}" --base-sha "${BASE_SHA}")"
  difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${CONVERTED}")"
  jq -c '.records' <<<"${CONVERTED}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"
fi

# 前回のセッションで GitHub に投稿しないまま残っている open なスレッドを再投入する
REBUILT="$(python3 "${STATE_PY}" rebuild --state "${STATE_FILE}" --repo "${REPO}" --pr "${PR}" --head-sha "${HEAD_SHA}" \
  --worktree "${WORKTREE}" --base-sha "${BASE_SHA}" --snapshot "${STATE_DIR}/difit-last.json" --snapshot-head-sha "${PREV_HEAD_SHA}")"
difit_import "${DIFIT_PORT}" "$(jq -c '.imports' <<<"${REBUILT}")"
jq -c '.records' <<<"${REBUILT}" | python3 "${STATE_PY}" append --state "${STATE_FILE}"

cat "${SESSION}"

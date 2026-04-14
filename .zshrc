# Golang settings
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export PATH="$HOME/.local/bin:$PATH"

## アーキテクチャに応じてhomebrewのパス変更
if [ `uname -m` = "arm64" ]; then
    typeset -U path PATH
    path=(
        $path
        /opt/homebrew/bin(N-/)
        /opt/homebrew/opt/python@3.9/libexec/bin(N-/)
        /opt/homebrew/opt/make/libexec/gnubin(N-/)
        /usr/local/bin(N-/)
    )
else
    export PATH=$PATH:/usr/local/bin/brew
fi

# direnv
export EDITOR=nvim
eval "$(direnv hook zsh)"

# Java settings
export JAVA_HOME=/opt/homebrew/opt/openjdk
export PATH=$PATH:$JAVA_HOME/bin
export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"

# make settings
export PATH="/usr/local/opt/make/libexec/gnubin:$PATH"

# Ruby settings
eval "$(rbenv init - zsh)"

if [ -e "${HOME}/.zshrc_local" ]; then
    source "${HOME}/.zshrc_local"
fi

if [ -e "${HOME}/.linuxbrewrc" ]; then
    source "${HOME}/.linuxbrewrc"
fi

# pure prompt settings (https://github.com/sindresorhus/pure)
fpath+=("$(brew --prefix)/share/zsh/site-functions")
autoload -U promptinit; promptinit
prompt pure

# コマンド実行前に時刻を表示し、計測開始
preexec() {
    echo -e "\033[34mS: $(date '+%Y-%m-%d %H:%M:%S')\033[0m"  # 青
    LAST_CMD="$1"
    _cmd_start=$SECONDS
    _cmd_name="${1%% *}"  # コマンド名だけ取り出す（引数を除く）
}

# コマンド実行後に時刻表示、長時間コマンド通知、ターミナルタイトル設定
precmd() {
    local exit_status=$?

    # 終了時刻を表示
    if [[ -n "$LAST_CMD" ]]; then
        echo -e "\033[32mE: $(date '+%Y-%m-%d %H:%M:%S')\033[0m"  # 緑
        LAST_CMD=""
    fi

    # 長時間コマンドの完了通知
    if [[ -n $_cmd_start ]]; then
        local elapsed=$(( SECONDS - _cmd_start ))

        # 除外したいインタラクティブコマンド一覧
        local excluded=(fzf vim nvim nano less more man htop top tig lazygit peco gh frl claude)

        if (( elapsed >= 10 )) && [[ ! " ${excluded[@]} " =~ " ${_cmd_name} " ]]; then
            afplay /System/Library/Sounds/Funk.aiff &
        fi

        unset _cmd_start _cmd_name
    fi

    # ターミナルタイトルの設定
    case "${TERM}" in
    kterm*|xterm)
        echo -ne "\033]0;${USER}@${HOST%%.*}:${PWD}\007"
        ;;
    esac
}

# You may need to manually set your language environment
export LANG=ja_JP.UTF-8

# charset of less command
export LESSCHARSET=utf-8

setopt extendedglob

# fzf settings
export FZF_DEFAULT_OPTS='--height 40% --reverse --border'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fd - cd to selected directory
fd() {
  local dir
  dir=$(find ${1:-.} -path '*/\.*' -prune \
                  -o -type d -print 2> /dev/null | fzf +m) &&
  cd "$dir"
}


# frl - ghqで管理しているリポジトリをfzfで選択してcdする
frl() {
  local selected=$(ghq list -p | fzf)
  [ -n "$selected" ] && cd "$selected"
}

# fgl - gitログをfzfで閲覧する (enterでshow、ctrl-dでdiff)
fgl() {
  local out shas sha q k
  while out=$(
      git log --graph --color=always \
          --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
      fzf --ansi --multi --no-sort --reverse --query="$q" \
          --print-query --expect=ctrl-d); do
    q=$(head -1 <<< "$out")
    k=$(head -2 <<< "$out" | tail -1)
    shas=$(sed '1,2d;s/^[^a-z0-9]*//;/^$/d' <<< "$out" | awk '{print $1}')
    [ -z "$shas" ] && continue
    if [ "$k" = ctrl-d ]; then
      git diff --color=always $shas | less -R
    else
      for sha in $shas; do
        git show --color=always $sha | less -R
      done
    fi
  done
}

# fbr - fzfでブランチを選択してcheckoutする
fbr() {
  local branches branch
  branches=$(git branch -vv) &&
  branch=$(echo "$branches" | fzf +m) &&
  git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}

# fst - fzfでstashを選択して表示する (enterでpop、ctrl-dでdrop)
fst() {
  local out k stash
  while out=$(
      git stash list --color=always |
      fzf --ansi --no-sort --reverse \
          --preview 'git stash show -p --color=always $(echo {} | cut -d: -f1)' \
          --preview-window=right:60% \
          --expect=ctrl-d); do
    k=$(head -1 <<< "$out")
    stash=$(tail -1 <<< "$out" | cut -d: -f1)
    [ -z "$stash" ] && break
    if [ "$k" = ctrl-d ]; then
      git stash drop "$stash"
    else
      git stash pop "$stash"
      break
    fi
  done
}

# git worktreeを追加する。gwa feature-aで、../feature-aにworktreeを追加し、cdする
gwa() {
    if git ls-remote --exit-code --heads origin "$1" > /dev/null 2>&1; then
        git worktree add --track -b "$1" "../$1" "origin/$1" && cd "../$1"
    else
        git worktree add "../$1" && cd "../$1"
    fi
}

# git worktreeを削除する。gwd feature-aで、../feature-aのworktreeを削除し、ブランチも削除する
gwd() {
    for branch in "$@"; do
        echo "Removing worktree and branch: $branch"
        git worktree remove --force "../$branch" && git branch -D "$branch"
    done
}

# ftmux - fzfでtmuxセッションを選択してアタッチ/切り替えする
ftmux() {
  local session
  session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --height 40% --reverse)
  if [[ -n $session ]]; then
    if [[ -n $TMUX ]]; then
      tmux switch-client -t "$session"
    else
      tmux attach-session -t "$session"
    fi
  fi
}


# alias
## git
alias g="git"
# ローカルのブランチを、main、develop、staging、releaseを除いた、mainへマージ済みのブランチを全て削除
alias gbclean="git branch --merged main | grep -vE '^\*|main$|develop$|staging$|release$' | xargs -I % git branch -d %"

# Deno settings
. "/Users/shimgo/.deno/env"
if [[ ":$FPATH:" != *":/Users/shimgo/.zsh/completions:"* ]]; then export FPATH="/Users/shimgo/.zsh/completions:$FPATH"; fi

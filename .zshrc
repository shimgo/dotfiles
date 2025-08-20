# Add deno completions to search path
if [[ ":$FPATH:" != *":/Users/shimgo/.zsh/completions:"* ]]; then export FPATH="/Users/shimgo/.zsh/completions:$FPATH"; fi
# Golang settings
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

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

# コマンド実行前に時刻を表示
preexec() {
    echo -e "\033[34mS: $(date '+%Y-%m-%d %H:%M:%S')\033[0m"  # 青
    LAST_CMD="$1"
}
# コマンド実行後に色付き時刻を表示
precmd() {
    local exit_status=$?
    if [[ -n "$LAST_CMD" ]]; then
        echo -e "\033[32mE: $(date '+%Y-%m-%d %H:%M:%S')\033[0m"  # 緑
        LAST_CMD=""
    fi
}

# Title of terminal
case "${TERM}" in
kterm*|xterm)
    precmd() {
        echo -ne "\033]0;${USER}@${HOST%%.*}:${PWD}\007"
    }
    ;;
esac

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

# cf - fuzzy cd from anywhere
# ex: cf word1 word2 ... (even part of a file name)
# zsh autoload function
cf() {
  local file

  file="$(locate -i -0 $@ | grep -Z -vE '~$' | fzf --read0 -0 -1)"

  if [[ -n $file ]]
  then
     if [[ -d $file ]]
     then
        cd -- $file
     else
        cd -- ${file:h}
     fi
  fi
}

frl() {
  local selected=$(ghq list -p | fzf)
  [ -n "$selected" ] && cd "$selected"
}

# fshow - git commit browser (enter for show, ctrl-d for diff)
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

# require 'git clone https://github.com/rupa/z.git ~/.zsh.d'
source ~/.zsh.d/z.sh

zs() {
    local res=$(z | sort -rn | cut -c 12- | fzf)
    if [ -n "$res" ]; then
        BUFFER+="cd $res"
        zle accept-line
    else
        return 1
    fi
}

# fbr - checkout git branch
fbr() {
  local branches branch
  branches=$(git branch -vv) &&
  branch=$(echo "$branches" | fzf +m) &&
  git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}

# git worktreeを追加する。gwa feature-aで、../feature-aにworktreeを追加し、cdする
gwa() {
    git worktree add "../$1" && cd "../$1"
}

# git worktreeを削除する。gwd feature-aで、../feature-aのworktreeを削除し、ブランチも削除する
gwd() {
    git worktree remove --force "../$1" && git branch -D "$1"
}

# tmux session selector with fzf
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
function git(){hub "$@"}

. "/Users/shimgo/.deno/env"

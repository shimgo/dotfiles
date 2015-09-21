#!/bin/bash

trap 'echo Error: $0:$LINENO stopped; exit 1' ERR INT
set -eu

. "$DOTPATH"/etc/lib/vital.sh

#if [ ${EUID:-${UID}} != 0 ]; then
#    log_info "${0:-zsh.sh} must be executed as user root."
#    log_info "you should run 'su root; chsh -s \$(which zsh)'"
#    exit
#fi

if has "brew"; then
    brew install global --with-exuberant-ctags --with-pygments
else
    log_fail "You need Homebrew"
    exit 1
fi


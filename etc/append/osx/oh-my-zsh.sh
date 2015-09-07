#!/bin/bash

trap 'echo Error: $0:$LINENO stopped; exit 1' ERR INT
set -eu

. "$DOTPATH"/etc/lib/vital.sh

#if [ ${EUID:-${UID}} != 0 ]; then
#    log_info "${0:-zsh.sh} must be executed as user root."
#    log_info "you should run 'su root; chsh -s \$(which zsh)'"
#    exit
#fi

curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh


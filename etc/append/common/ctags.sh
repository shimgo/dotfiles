#!/bin/bash

trap 'echo Error: $0:$LINENO stopped; exit 1' ERR INT
set -eu

. "$DOTPATH"/etc/lib/vital.sh

#if [ ${EUID:-${UID}} != 0 ]; then
#    log_info "${0:-zsh.sh} must be executed as user root."
#    log_info "you should run 'su root; chsh -s \$(which zsh)'"
#    exit
#fi

if is_osx; then
    if [ -x "/usr/local/bin/ctags" ]; then
        log_info "ctags already has been installed"
        exit
    fi
    if has "brew"; then
        brew install ctags
    else
        log_fail "You need Homebrew"
        exit 1
    fi
elif is_linux; then
    if ! has "ctags"; then
        if has "apt-get"; then
            sudo apt-get -y install ctags 
        elif has "yum"; then
            sudo yum -y install ctags
        else
            log_fail "You need apt-get or yum"
            exit 1
        fi
    else
        log_info "ctags already has been installed"
    fi
else
    log_fail "supports only mac or linux"
    exit 1
fi
 

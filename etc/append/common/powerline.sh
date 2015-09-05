#!/bin/bash

trap 'echo Error: $0:$LINENO stopped; exit 1' ERR INT
set -eu

. "$DOTPATH"/etc/lib/vital.sh

if [ ${EUID:-${UID}} != 0 ]; then
    log_info "${0:-zsh.sh} must be executed as user root."
    log_info "you should run 'su root; chsh -s \$(which zsh)'"
    exit
fi

if ! has "python"; then
    if is_osx; then
        if has "brew"; then
            brew install python
        else
            log_fail "You need Homebrew"
            exit 1
        fi
    elif is_linux; then
        if has "apt-get"; then
            sudo apt-get -y install python
        elif has "yum"; then
            sudo yum -y install python
        else
            log_fail "You need apt-get or yum"
            exit 1
        fi
    else
        log_fail "supports only mac or linux"
        exit 1
    fi
fi

if ! has "pip"; then
    if is_linux; then
        curl -kL https://raw.github.com/pypa/pip/master/contrib/get-pip.py | python
        pip install --user powerline-status
    else
        log_info "you need pip"
        exit 1
    fi
else
    pip install --user powerline-status
fi
 

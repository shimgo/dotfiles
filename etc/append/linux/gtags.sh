#!/bin/bash

trap 'echo Error: $0:$LINENO stopped; exit 1' ERR INT
set -eu

. "$DOTPATH"/etc/lib/vital.sh

#if [ ${EUID:-${UID}} != 0 ]; then
#    log_info "${0:-zsh.sh} must be executed as user root."
#    log_info "you should run 'su root; chsh -s \$(which zsh)'"
#    exit
#fi
if [ -r "powerline" ]; then
    log_info "powerline already has been installed"
    exit
fi
if ! has "python"; then
    if has "apt-get"; then
        sudo apt-get -y install python
    elif has "yum"; then
        sudo yum -y install python
    else
        log_fail "You need apt-get or yum"
        exit 1
    fi
fi

if ! has "pip"; then
    curl -kL https://bootstrap.pypa.io/get-pip.py | python
    pip install --user Pygments
else
    pip install --user Pygments
fi
 
if ! has "ctags"; then
    if has "apt-get"; then
        sudo apt-get -y install exuberant-ctags
    elif has "yum"; then
        sudo yum -y install ctags
    else
        log_fail "You need apt-get or yum"
        exit 1
    fi
    log_info "Download the latest source archive from following address"
    log_info "http://www.gnu.org/software/global/download.html"
    log_info "And execute following commands."
    log_info "$ tar xf global-x.x.x.tar.gz"
    log_info "$ cd global-x.x.x"
    log_info "$ ./configure"
    log_info "$ make"
    log_info "$ sudo make install"
fi


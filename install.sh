DOTPATH=~/dotfiles

# git が使えるなら git
if has "git"; then
    git clone --recursive "https://github.com/shin-m/" "$DOTPATH"
        
# 使えない場合は curl か wget を使用する
elif has "curl" || has "wget"; then
    tarball="https://github.com/shin-m/dotfiles/archive/master.tar.gz"
                
    # どっちかでダウンロードして，tar に流す
    if has "curl"; then
        curl -L "$tarball"
        
    elif has "wget"; then
        wget -O - "$tarball"
            
    fi | tar xv -

    # 解凍したら，DOTPATH に置く
    mv -f dotfiles-master "$DOTPATH"

else
    die "curl or wget required"
fi

cd ~/.dotfiles
if [ $? -ne 0 ]; then
die "not found: $DOTPATH"
fi

# 移動できたらリンクを実行する
DOT_FILES=(
#  .zsh
#  .zshrc
#  .zshrc.custom
#  .zshrc.alias
#  .zshrc.linux
#  .zshrc.osx
#  .ctags
#  .emacs.el
#  .gdbinit
#  .gemrc
  .gitconfig
#  .gitignore
#  .inputrc
#  .irbrc
#  .sbtconfig
#  .screenrc
  .vimrc
#  .vim
#  .vrapperrc import.scala
#  .tmux.conf
#  .dir_colors
#  .rdebugrc
#  .pryrc
#  .percol.d
)

for file in ${DOT_FILES[@]}
do
    ln -sv $HOME/dotfiles/$file $HOME/$file
done

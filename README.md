# セットアップ
初回clone時
```
git clone --recursive https://github.com/shimgo/dotfiles.git
```

clone済みでsubmoduleだけcloneしたいとき
```
git submodule update --init --recursive
```

## NERDTreeアイコンの設定
```
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
```

## Language Serverのインストール
インストールしたいFileTypeのファイルを開いた状態で
```
:LspInstallServer
```

## vimにプラグインを追加する
サブモジュールとして追加する。  
.vim/pack/all/start/に追加すればvim起動時に必ずロードされる。  
.vim/pack/all/opt/に追加すれば起動時にロードされないので、必要になったタイミングで`packadd xxxxx`で読み込む必要がある
```
git submodule add https://github.com/user/xxxxx.git .vim/pack/all/start/xxxxx
```

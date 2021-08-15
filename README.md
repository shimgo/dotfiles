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


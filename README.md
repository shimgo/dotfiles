# 共通

## ファイラのアイコンのpatched fontの設定
https://www.nerdfonts.com/

```
brew tap homebrew/cask-fonts
brew install --cask font-hack-nerd-font
```

その後、iTerm2でフォントにHack Nerd Fontを選択


# Neovim

## プラグイン管理

インストール
```
:PlugInstall
```

リセット
```
:PlugClean
```

## Language Server
インストールしたいFileTypeのファイルを開いた状態で
```
:LspInstall
```

状態を見るときは
```
:LspInfo
```

## denops.vim関連の設定

Denoのインストール
```
brew install deno
```

以下のコマンドでパスが出てくればOK
```
:echo exepath('deno')
/opt/homebrew/bin/deno
```

## fzf-lua

fdのインストール。これがないとファイル検索が動かなかった。fzfのruntime pathの問題かも？
```
brew install fd
```

# Vim

## セットアップ
初回clone時
```
git clone --recursive https://github.com/shimgo/dotfiles.git
```

clone済みでsubmoduleだけcloneしたいとき
```
git submodule update --init --recursive
```

## Language Server
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

local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.config/nvim/plugged')

Plug 'nvim-tree/nvim-tree.lua'
Plug 'nvim-tree/nvim-web-devicons'
Plug('nvim-treesitter/nvim-treesitter', {['do']= ':TSUpdate' })
Plug 'nvim-treesitter/playground'
Plug 'Mofiqul/vscode.nvim'

-- LSP {{{
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'
Plug 'neovim/nvim-lspconfig'
-- }}}

-- コード補完 {{{
-- 補完
Plug('Saghen/blink.cmp', { tag = 'v1.*' }) -- プリビルドのマッチャーを自動ダウンロードするためにtag指定している
-- 関数シグネチャの表示
Plug 'ray-x/lsp_signature.nvim'
-- }}}

-- ファイル検索 {{{
-- fzf-lua
-- grep、ファイル検索、gitの検索など
-- brew install fd ripgrep が必要
Plug 'ibhagwan/fzf-lua'
-- }}}

-- Git {{{
-- バッファに変更箇所を表示、変更箇所にカーソルを移動する
Plug 'airblade/vim-gitgutter'
-- Gitの操作
Plug 'tpope/vim-fugitive'
-- GitHubのpermalink取得
Plug 'linrongbin16/gitlinker.nvim'
-- diffをGitHubっぽい表示にして見やすくする。ファイルの変更履歴をdiffで表示したりできる
Plug 'sindrets/diffview.nvim'
-- PRレビュー
Plug 'pwntester/octo.nvim'
-- }}}

-- Copilot {{{
Plug 'github/copilot.vim'
Plug 'nvim-lua/plenary.nvim'
Plug 'CopilotC-Nvim/CopilotChat.nvim'
Plug 'olimorris/codecompanion.nvim'
-- }}}

-- タブ・バッファ関連 {{{
Plug 'lewis6991/gitsigns.nvim' -- barbar.nvimのGitのステータス表示に必要（optional）
-- タブ表示
Plug 'romgrk/barbar.nvim'
-- }}}
-- Terminal {{{
-- Neovim内のターミナルでさらにNeovimを開いても、ネストしたNeovimセッションを開始せず、最初に開いたNeovim内のバッファとして開く
Plug 'willothy/flatten.nvim'
-- ターミナルモードでVimっぽく編集できる
Plug 'chomosuke/term-edit.nvim'
Plug 'akinsho/toggleterm.nvim'
-- }}}

-- コメントアウト
-- ノーマルモードでgccでコメントアウト
Plug 'tpope/vim-commentary'

-- ウィンドウサイズ変更
Plug 'simeji/winresizer'

-- バッファを閉じるための便利コマンドを提供する
Plug 'kazhala/close-buffers.nvim'

-- 置換の高機能版
Plug 'tpope/vim-abolish'

Plug 'tpope/vim-surround'

-- 画面に関数の実装が収まらなかった場合に、関数定義を画面の上部に表示する
Plug 'nvim-treesitter/nvim-treesitter-context'

-- スクロールのアニメーションをスムーズにし、スクロール時にカーソルを固定する
Plug 'karb94/neoscroll.nvim'

-- ステータスライン
Plug 'nvim-lualine/lualine.nvim'

vim.call('plug#end')

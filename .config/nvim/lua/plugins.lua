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
Plug 'vim-denops/denops.vim' -- ddc.vimに必要
-- ddc.vim本体。単体では動かない。sourceとfilterをインストールする必要がある
-- https://github.com/topics/ddc-source
-- https://github.com/topics/ddc-filter
Plug 'Shougo/ddc.vim'
-- ddcで使うUI
-- https://github.com/topics/ddc-ui
Plug 'Shougo/pum.vim'
Plug 'Shougo/ddc-ui-pum'
-- カーソル周辺の既出単語を補完するsource
Plug 'Shougo/ddc-source-around'
-- ファイル名を補完するsource
Plug 'LumaKernel/ddc-source-file'
-- LSPのsource
Plug 'Shougo/ddc-source-nvim-lsp'
-- 補完時にすでに入力済みの文字を除いて補完するためのfilter
Plug 'Shougo/ddc-filter-converter_remove_overlap'
-- 曖昧検索のfilter
Plug 'tani/ddc-fuzzy'
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
-- }}}

vim.call('plug#end')

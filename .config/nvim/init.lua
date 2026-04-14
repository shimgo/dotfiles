-- vimというグローバルが認識されるようにする
vim = vim or {}

require("plugins")

-- クリップボード共有
vim.opt.clipboard:append({ "unnamedplus" }) -- レジスタとクリップボードを共有

-- ファイル
vim.opt.fileencoding = "utf-8" -- エンコーディングをUTF-8に設定
vim.opt.swapfile = false -- スワップファイルを作成しない
vim.opt.helplang = "ja" -- ヘルプファイルの言語は日本語
vim.opt.hidden = true -- バッファを切り替えるときにファイルを保存しなくてもOKに
-- バッファ移動時・フォーカス喪失時に自動保存
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  callback = function()
    if vim.bo.modified and vim.bo.buftype == "" and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! write")
    end
  end,
})

-- 表示
vim.opt.number = true -- 行番号を表示
vim.opt.wrap = false -- テキストの自動折り返しを無効に
-- Markdownファイルではwrapをデフォルトで有効にする
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.wo.wrap = true
  end,
})
-- wrap切り替え
vim.keymap.set('n', '<leader>w', function()
  vim.wo.wrap = not vim.wo.wrap
end)
vim.opt.termguicolors = true -- 24ビットカラーを有効化（vscode.nvim等のカラースキームに必要）

-- インデント
vim.opt.shiftwidth = 4 -- シフト幅を4に設定する
vim.opt.tabstop = 4 -- タブ幅を4に設定する

-- 全角スペース、タブ、空白のハイライト
vim.opt.list = true
vim.opt.listchars='tab:>.,trail:_,extends:>,precedes:<,nbsp:%'

-- ファイルごとの設定 {{{
-- :echo &filetype で現在のバッファのファイルタイプを確認できる。バッファに出したいときは:put=&filetype
-- sw=shiftwidth, sts=softtabstop, ts=tabstop, et=expandtabの略
-- tabstop: タブ文字をスペース何も自分の表示にするか
-- expandtab: TABキーを押したときにタブ文字の代わりにスペースを挿入するか
-- softtabstop: TABキーを押したときにスペースを何個挿入するか
local filetypes = {
  typescriptreact = {sw = 2, sts = 2, ts = 2, et = true},
  graphql = {sw = 2, sts = 2, ts = 2, et = true},
  lua = {sw = 2, sts = 2, ts = 2, et = true},
}
-- autocmdの設定
for ft, opts in pairs(filetypes) do
  vim.api.nvim_create_autocmd("FileType", {
    pattern = ft,
    callback = function()
      vim.bo.shiftwidth = opts.sw
      vim.bo.softtabstop = opts.sts
      vim.bo.tabstop = opts.ts
      vim.bo.expandtab = opts.et
    end
  })
end
-- }}}


-- grepをrgに変更
if vim.fn.executable('rg') == 1 then
  vim.opt.grepprg='rg -S --vimgrep'
end
vim.api.nvim_create_autocmd({"QuickfixCmdPost"}, {pattern = {"make", "grep", "grepadd", "vimgrep"}, command = "copen"})

-- Smart ignore case
-- 両方ONにしないとFooで検索したときにfooやFOOもヒットしてしまう。
vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.cursorline = true -- カーソル行をハイライト

-- 折りたたみ
-- fold method
-- manual – 自分で範囲選択して折りたたみ
-- indent – インデント範囲
-- marker – {{{ と }}} で囲まれた範囲
-- expr – foldexpr による折りたたみレベル指定
-- syntax – 現在の syntax に応じた折りたたみ
vim.opt.foldmethod = 'indent'
vim.o.foldenable = false
-- }}}

-- キー設定 {{{
vim.g.mapleader = ' '
vim.g.maplocalleader = ","
vim.keymap.set('i', 'jj', '<ESC>')
vim.keymap.set('v', '<C-j><C-j>', '<ESC>')
vim.keymap.set('t', 'jj', '<C-\\><C-n>')
vim.keymap.set('n', ';', ':')
vim.keymap.set('n', ':', ';')
vim.keymap.set('v', ';', ':')
vim.keymap.set('v', ':', ';')
vim.keymap.set('n', '<leader>h', '^')
vim.keymap.set('v', '<leader>h', '^')
vim.keymap.set('n', '<leader>l', '$')
vim.keymap.set('v', '<leader>l', '$')
vim.keymap.set('n', '<C-h>', ':<C-u>%s/') -- 置換
vim.keymap.set('n', '<C-k>', '<C-y>') -- カーソルを固定して上にスクロール
vim.keymap.set('n', '<C-j>', '<C-e>') -- カーソルを固定して下にスクロール
vim.keymap.set('c', '<C-a>', '<Home>', { noremap = true, desc = "コマンドラインモードでカーソルを行頭へ移動" })
vim.keymap.set('c', '<C-e>', '<End>', { noremap = true, desc = "コマンドラインモードでカーソルを行末へ移動" })

vim.keymap.set('n', 'gf', 'gF', { noremap = true, desc = "カーソル下のファイルパスのファイルを開いてその行数にジャンプ" })
vim.keymap.set('n', 'gF', 'gf', { noremap = true, desc = "カーソル下のファイルパスのファイルを開く" })

-- jq
vim.keymap.set('n', '<leader>xjb', ':%! jq .<CR>', { desc = "jqでJSONをフォーマット" })

-- Quickfix
vim.keymap.set('n', 'sqq', '<C-w><C-w><C-w>q') -- クイックフィックスを閉じる
vim.keymap.set('n', '<C-n>', ':cn<CR>')
vim.keymap.set('n', '<C-p>', ':cp<CR>')
vim.keymap.set("n", "[q", "<cmd>colder<cr>", { desc = "前のquickfixリストを開く" })
vim.keymap.set("n", "]q", "<cmd>cnewer<cr>", { desc = "次のquickfixリストを開く" })

-- キー無効化 {{{
vim.keymap.set('n', 's', '<Nop>') -- 使わない動作なので潰してウィンドウ操作のキーに使う
-- }}}

-- ウィンドウ関連 {{{
vim.keymap.set('n', 'ss', ':<C-u>split<CR>')
vim.keymap.set('n', 'sv', ':<C-u>vsplit<CR>')
vim.keymap.set('n', 'sw', '<C-w>w')
vim.keymap.set('n', 'sj', '<C-w>j')
vim.keymap.set('n', 'sk', '<C-w>k')
vim.keymap.set('n', 'sl', '<C-w>l')
vim.keymap.set('n', 'sh', '<C-w>h')
vim.keymap.set('v', 'sj', '<C-w>j')
vim.keymap.set('v', 'sk', '<C-w>k')
vim.keymap.set('v', 'sl', '<C-w>l')
vim.keymap.set('v', 'sh', '<C-w>h')
vim.keymap.set('n', 'sJ', '<C-w>J')
vim.keymap.set('n', 'sK', '<C-w>K')
vim.keymap.set('n', 'sL', '<C-w>L')
vim.keymap.set('n', 'sH', '<C-w>H')
vim.keymap.set('n', 'sr', '<C-w>r')
vim.keymap.set('n', 's=', '<C-w>=')
vim.keymap.set('n', 'sQ', ':<C-u>q<CR>')
vim.keymap.set('n', 'sfQ', ':<C-u>q!<CR>')
vim.keymap.set('n', 'sa', ':<C-u>qa<CR>')
-- }}}

-- ターミナル関連 {{{
-- Claude Codeを新しいターミナルで開く
vim.keymap.set('n', '<leader>ac', function()
  vim.cmd("vsplit | wincmd l | terminal zsh -i -c 'claude --dangerously-skip-permissions'")
  vim.cmd('startinsert')
end, { desc = "Claude Code terminal" })
-- }}}

-- winresizer {{{
-- winresizer の開始キー
vim.g.winresizer_start_key = '<C-w>'
-- }}}

-- nvim-tree.lua {{{
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
local function my_on_attach(bufnr)
  local api = require "nvim-tree.api"

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  -- カーソルで指定したディレクトリでターミナルを開く関数
  local function open_terminal_in_dir()
    local node = api.tree.get_node_under_cursor()

    if not node then return end

    -- ディレクトリかファイルかを判定
    local path = node.absolute_path
    local dir = node.type == "directory" and path or vim.fn.fnamemodify(path, ":h")

    -- 水平分割でターミナルを開く場合
    vim.cmd("split")
    vim.cmd("terminal")

    -- ディレクトリに移動
    vim.fn.chansend(vim.b.terminal_job_id, "cd " .. vim.fn.shellescape(dir) .. "\n")
  end

  -- BEGIN_DEFAULT_ON_ATTACH
  vim.keymap.set('n', '<C-]>', api.tree.change_root_to_node,          opts('CD'))
  vim.keymap.set('n', '<C-e>', api.node.open.replace_tree_buffer,     opts('Open: In Place'))
  vim.keymap.set('n', '<C-k>', api.node.show_info_popup,              opts('Info'))
  vim.keymap.set('n', '<C-r>', api.fs.rename_sub,                     opts('Rename: Omit Filename'))
  vim.keymap.set('n', '<C-t>', api.node.open.tab,                     opts('Open: New Tab'))
  vim.keymap.set('n', '<C-v>', api.node.open.vertical,                opts('Open: Vertical Split'))
  vim.keymap.set('n', '<C-s>', api.node.open.horizontal,              opts('Open: Horizontal Split'))
  vim.keymap.set('n', '<BS>',  api.node.navigate.parent_close,        opts('Close Directory'))
  vim.keymap.set('n', '<CR>',  api.node.open.no_window_picker,        opts('Open: No Window Picker'))
  vim.keymap.set('n', '<Tab>', api.node.open.preview,                 opts('Open Preview'))
  vim.keymap.set('n', '>',     api.node.navigate.sibling.next,        opts('Next Sibling'))
  vim.keymap.set('n', '<',     api.node.navigate.sibling.prev,        opts('Previous Sibling'))
  -- vim.keymap.set('n', '.',     api.node.run.cmd,                      opts('Run Command'))
  vim.keymap.set('n', '-',     api.tree.change_root_to_parent,        opts('Up'))
  vim.keymap.set('n', 'a',     api.fs.create,                         opts('Create'))
  vim.keymap.set('n', 'bd',    api.marks.bulk.delete,                 opts('Delete Bookmarked'))
  vim.keymap.set('n', 'bmv',   api.marks.bulk.move,                   opts('Move Bookmarked'))
  vim.keymap.set('n', 'B',     api.tree.toggle_no_buffer_filter,      opts('Toggle Filter: No Buffer'))
  vim.keymap.set('n', 'c',     api.fs.copy.node,                      opts('Copy'))
  vim.keymap.set('n', 'C',     api.tree.toggle_git_clean_filter,      opts('Toggle Filter: Git Clean'))
  vim.keymap.set('n', '[c',    api.node.navigate.git.prev,            opts('Prev Git'))
  vim.keymap.set('n', ']c',    api.node.navigate.git.next,            opts('Next Git'))
  vim.keymap.set('n', 'd',     api.fs.remove,                         opts('Delete'))
  vim.keymap.set('n', 'D',     api.fs.trash,                          opts('Trash'))
  vim.keymap.set('n', 'E',     api.tree.expand_all,                   opts('Expand All'))
  vim.keymap.set('n', 'e',     api.fs.rename_basename,                opts('Rename: Basename'))
  vim.keymap.set('n', ']e',    api.node.navigate.diagnostics.next,    opts('Next Diagnostic'))
  vim.keymap.set('n', '[e',    api.node.navigate.diagnostics.prev,    opts('Prev Diagnostic'))
  vim.keymap.set('n', 'F',     api.live_filter.clear,                 opts('Clean Filter'))
  vim.keymap.set('n', 'f',     api.live_filter.start,                 opts('Filter'))
  vim.keymap.set('n', 'g?',    api.tree.toggle_help,                  opts('Help'))
  vim.keymap.set('n', 'gy',    api.fs.copy.absolute_path,             opts('Copy Absolute Path'))
  vim.keymap.set('n', '.',     api.tree.toggle_hidden_filter,         opts('Toggle Filter: Dotfiles'))
  vim.keymap.set('n', 'I',     api.tree.toggle_gitignore_filter,      opts('Toggle Filter: Git Ignore'))
  vim.keymap.set('n', 'J',     api.node.navigate.sibling.last,        opts('Last Sibling'))
  vim.keymap.set('n', 'K',     api.node.navigate.sibling.first,       opts('First Sibling'))
  vim.keymap.set('n', ',',     api.marks.toggle,                      opts('Toggle Bookmark')) -- デフォルトから変えた
  vim.keymap.set('n', 'o',     api.node.open.edit,                    opts('Open'))
  vim.keymap.set('n', 'O',     api.node.open.no_window_picker,        opts('Open: No Window Picker'))
  vim.keymap.set('n', 'p',     api.fs.paste,                          opts('Paste'))
  vim.keymap.set('n', 'H',     api.node.navigate.parent,              opts('Parent Directory'))
  vim.keymap.set('n', 'q',     api.tree.close,                        opts('Close'))
  vim.keymap.set('n', 'r',     api.fs.rename,                         opts('Rename'))
  vim.keymap.set('n', 'R',     api.tree.reload,                       opts('Refresh'))
  -- vim.keymap.set('n', 's',     api.node.run.system,                   opts('Run System'))
  vim.keymap.set('n', 'S',     api.tree.search_node,                  opts('Search'))
  vim.keymap.set('n', 'U',     api.tree.toggle_custom_filter,         opts('Toggle Filter: Hidden'))
  vim.keymap.set('n', 'W',     api.tree.collapse_all,                 opts('Collapse'))
  vim.keymap.set('n', 'x',     api.fs.cut,                            opts('Cut'))
  vim.keymap.set('n', 'y',     api.fs.copy.filename,                  opts('Copy Name'))
  vim.keymap.set('n', 'Y',     api.fs.copy.relative_path,             opts('Copy Relative Path'))
  vim.keymap.set('n', '<2-LeftMouse>',  api.node.open.edit,           opts('Open'))
  vim.keymap.set('n', '<2-RightMouse>', api.tree.change_root_to_node, opts('CD'))
  -- END_DEFAULT_ON_ATTACH
  vim.keymap.set("n", "t", open_terminal_in_dir, { buffer = bufnr, noremap = true, silent = true, desc = "Open terminal in directory" })
end

-- pass to setup along with your other options
require("nvim-tree").setup {
  on_attach = my_on_attach,
  view = {
    width = 60,
  },
  live_filter = {
    always_show_folders = false,
  },
  actions = {
    open_file = {
      window_picker = {
        enable = true,
        picker = "default",
        chars = "asdfrewq",
        exclude = {
          filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
          buftype = { "nofile", "terminal", "help" },
        },
      },
    }
  }
}
vim.keymap.set('n', '<leader>ft', ':NvimTreeToggle<CR>')
vim.keymap.set('n', '<leader>fb', ':NvimTreeFindFile<CR>') -- 現在のバッファのファイルを指定した状態でファイラを開く
vim.keymap.set('n', '<leader>fs', ':NvimTreeFocus<CR>') -- ファイラを開いてないなら開き、開いているならファイラにカーソルを移す
vim.keymap.set('n', '<leader>fc', ':NvimTreeOpen pwd<CR>') -- カレントディレクトリを開く

-- }}}

-- }}}

-- バッファ関連 {{{
vim.keymap.set('n', 'sfq', ':<C-u>bd!<CR>')
vim.keymap.set('n', 'sb', ':<C-u>enew<CR>')

-- function _G.EBufdelete()
--     local currentBufNum = vim.api.nvim_get_current_buf()
--     local alternateBufNum = bufnr("#")
-- 
--     if buflisted(alternateBufNum) then
--         vim.cmd('buffer #')
--     else
--         vim.cmd('bnext')
--     end
-- 
--     if buflisted(currentBufNum) then
--         vim.cmd("silent bwipeout"..currentBufNum)
--         -- recover buffer on window if bwipeout failed
--         if bufloaded(currentBufNum) ~= 0 then
--             vim.cmd("buffer "..currentBufNum)
--         end
--     end
-- end
-- vim.keymap.set('n', 'sq', '<cmd>lua EBufdelete()<CR>')

-- }}}

-- タブ関連 {{{
vim.keymap.set('n', 'sN', 'gt')
vim.keymap.set('n', 'sP', 'gT')
vim.keymap.set('n', 'so', '<C-w>_<C-w>|')
vim.keymap.set('n', 'st', ':<C-u>tabnew<CR>')
vim.keymap.set('n', 'sT', ':<C-u>Unite tab<CR>')
-- }}}

-- カーソル関連 {{{
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'j', 'gj')
vim.keymap.set('n', 'k', 'gk')
vim.keymap.set('n', 'k', 'gk')
vim.keymap.set('n', 'k', 'gk')
-- }}}

-- 設定ファイル関連 {{{
-- 再読み込み関数
function _G.ReloadConfig()
  for name,_ in pairs(package.loaded) do
    -- ~/.config/nvim/lua/xxxx/ 以下のモジュールを、exclude-meを除いてクリア
    if name:match('^xxxx') and not name:match('exclude-me') then
      package.loaded[name] = nil
    end
  end

  dofile(vim.env.MYVIMRC)
  vim.notify("Nvim configuration reloaded!", vim.log.levels.INFO)
end
vim.keymap.set('n', '<leader>vr', '<cmd>lua ReloadConfig()<CR>')
vim.keymap.set('n', '<Leader>ve', '<cmd>e ~/.config/nvim/init.lua<cr>')
-- }}}
-- }}}

-- nvim-treesitter {{{
-- nvim-treesitterの新バージョンはクエリを runtime/queries/ に配置するため、rtpに追加する
-- prependで追加し、内蔵言語のパーサーもTSInstallで更新してクエリと整合させる
vim.opt.rtp:prepend(vim.fn.stdpath('config') .. '/plugged/nvim-treesitter/runtime')

-- Neovim 0.11+ではtreesitterのハイライトはNeovim組み込み機能になった
-- vim.treesitter.start()で有効化する
vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

-- nvim-treesitter-textobjects {{{
local ts_select = require('nvim-treesitter-textobjects.select')
local ts_move = require('nvim-treesitter-textobjects.move')
require('nvim-treesitter-textobjects').setup({
  select = { lookahead = true },
  move = { set_jumps = true },
})

-- テキストオブジェクト選択
vim.keymap.set({ 'x', 'o' }, 'af', function() ts_select.select_textobject('@function.outer') end, { desc = 'Select outer function' })
vim.keymap.set({ 'x', 'o' }, 'if', function() ts_select.select_textobject('@function.inner') end, { desc = 'Select inner function' })
vim.keymap.set({ 'x', 'o' }, 'ac', function() ts_select.select_textobject('@class.outer') end, { desc = 'Select outer class' })
vim.keymap.set({ 'x', 'o' }, 'ic', function() ts_select.select_textobject('@class.inner') end, { desc = 'Select inner class' })
vim.keymap.set({ 'x', 'o' }, 'as', function() ts_select.select_textobject('@local.scope', 'locals') end, { desc = 'Select language scope' })

-- テキストオブジェクト移動
vim.keymap.set({ 'n', 'x', 'o' }, ']m', function() ts_move.goto_next_start('@function.outer') end, { desc = '次の関数の開始位置に移動' })
vim.keymap.set({ 'n', 'x', 'o' }, ']c', function() ts_move.goto_next_start('@class.outer') end, { desc = '次のクラスの開始位置に移動' })
vim.keymap.set({ 'n', 'x', 'o' }, ']M', function() ts_move.goto_next_end('@function.outer') end, { desc = '次の関数の終了位置に移動' })
vim.keymap.set({ 'n', 'x', 'o' }, ']C', function() ts_move.goto_next_end('@class.outer') end, { desc = '次のクラスの終了位置に移動' })
vim.keymap.set({ 'n', 'x', 'o' }, '[m', function() ts_move.goto_previous_start('@function.outer') end, { desc = '前の関数の開始位置に移動' })
vim.keymap.set({ 'n', 'x', 'o' }, '[c', function() ts_move.goto_previous_start('@class.outer') end, { desc = '前のクラスの開始位置に移動' })
vim.keymap.set({ 'n', 'x', 'o' }, '[M', function() ts_move.goto_previous_end('@function.outer') end, { desc = '前の関数の終了位置に移動' })
vim.keymap.set({ 'n', 'x', 'o' }, '[C', function() ts_move.goto_previous_end('@class.outer') end, { desc = '前のクラスの終了位置に移動' })
-- }}}

-- 次のトップレベル関数に移動
local function goto_next_top_level_function()
  local ok, parser = pcall(vim.treesitter.get_parser)
  if not ok or not parser then return end

  local tree = parser:parse()[1]
  local root = tree:root()
  local cursor_row = vim.fn.line('.') - 1

  local next_func = nil
  local min_row = math.huge

  -- source_fileの直下の子要素のみをチェック
  for child in root:iter_children() do
    if child:type() == "function_declaration" or
       child:type() == "method_declaration" then
      local start_row = child:start()
      if start_row > cursor_row and start_row < min_row then
        min_row = start_row
        next_func = child
      end
    end
  end

  if next_func then
    local start_row, start_col = next_func:start()
    vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
  end
end

-- 前のトップレベル関数に移動
local function goto_prev_top_level_function()
  local ok, parser = pcall(vim.treesitter.get_parser)
  if not ok or not parser then return end

  local tree = parser:parse()[1]
  local root = tree:root()
  local cursor_row = vim.fn.line('.') - 1

  local prev_func = nil
  local max_row = -1

  for child in root:iter_children() do
    if child:type() == "function_declaration" or
       child:type() == "method_declaration" then
      local start_row = child:start()
      if start_row < cursor_row and start_row > max_row then
        max_row = start_row
        prev_func = child
      end
    end
  end

  if prev_func then
    local start_row, start_col = prev_func:start()
    vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
  end
end

vim.keymap.set('n', ']f', goto_next_top_level_function, { desc = 'Go to next top-level function' })
vim.keymap.set('n', '[f', goto_prev_top_level_function, { desc = 'Go to previous top-level function' })
vim.keymap.set('v', ']f', goto_next_top_level_function, { desc = 'Go to next top-level function' })
vim.keymap.set('v', '[f', goto_prev_top_level_function, { desc = 'Go to previous top-level function' })
-- }}}

-- vscode.nvim {{{
require('vscode').setup({
    -- Alternatively set style in setup
    -- style = 'light'

    -- Enable transparent background
    transparent = true,

    -- Enable italic comment
    italic_comments = true,
})
require('vscode').load()
-- }}}

-- mason.nvim, mason-lspconfig.nvim, lspconfig {{{
-- It's important that you set up the plugins in the following order:
-- 1. mason.nvim
-- 2. mason-lspconfig.nvim
-- 3. Setup servers via lspconfig
require("mason").setup()
require('mason-lspconfig').setup({
  -- これをtrueにしてても、require('lspconfig').graphql.setup({})を呼び出さないと正しく動作しなかった。
  -- また、trueにした状態で、setupを呼び出すとLSPを二重起動してしまうのでfalseにしておく。
  automatic_enable = false
})
-- LSPごとのセットアップ
-- https://neovim.io/doc/user/lsp.html#vim.lsp.config()
-- masonでインストールしたLSPも個別に設定・有効化する必要がある（mason-lspconfigのautomatic_enableをfalseにしてるので）
vim.lsp.config('graphql', {})
vim.lsp.config('gopls', {})
vim.lsp.config('lua_ls', {
  on_init = function(client)
    local path = client.workspace_folders[1].name
    if not vim.uv.fs_stat(path..'/.luarc.json') and not vim.uv.fs_stat(path..'/.luarc.jsonc') then
      client.config.settings = vim.tbl_deep_extend('force', client.config.settings, {
        Lua = {
          diagnostics = {
            globals = {'vim'}, -- "undefined global vim"の警告が出ないようにする
          },
        }
      })

      client.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
    end
    return true
  end
})
vim.lsp.config('typos_lsp', {
    -- Logging level of the language server. Logs appear in :LspLog. Defaults to error.
    cmd_env = { RUST_LOG = "error" },
    init_options = {
        -- How typos are rendered in the editor, can be one of an Error, Warning, Info or Hint.
        -- Defaults to error.
        diagnosticSeverity = "Info"
    }
})
vim.lsp.enable({'graphql', 'gopls', 'lua_ls', 'typos_lsp'})

-- lsp-signature.nvim
require("lsp_signature").setup({
  max_height = 20,
})
vim.keymap.set('n', 'gk', function() require('lsp_signature').toggle_float_win() end) -- カーソル上の関数の引数のヒントを表示

-- 保存時のフォーマット
vim.api.nvim_create_augroup('MyAutoCmd', { clear = true })
vim.api.nvim_create_autocmd({ 'BufWritePre' }, {
    pattern = "*.go",
    callback = function()
      local clients = vim.lsp.get_clients({ bufnr = 0, name = "gopls" })
      if #clients == 0 then return end
      local enc = clients[1].offset_encoding or "utf-16"
      local params = vim.lsp.util.make_range_params(0, enc)
      params.context = {only = {"source.organizeImports"}}
      -- buf_request_sync defaults to a 1000ms timeout. Depending on your
      -- machine and codebase, you may want longer. Add an additional
      -- argument after params if you find that you have to write the file
      -- twice for changes to be saved.
      -- E.g., vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 3000)
      local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params)
      for cid, res in pairs(result or {}) do
        for _, r in pairs(res.result or {}) do
          if r.edit then
            local client = vim.lsp.get_clients({ id = cid })[1]
            local client_enc = client and client.offset_encoding or "utf-16"
            vim.lsp.util.apply_workspace_edit(r.edit, client_enc)
          end
        end
      end
      vim.lsp.buf.format({async = false})
    end
  })
-- }}}

-- Global mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float) -- エラー内容をfloating windowで表示。その状態で同じキーを押すとfloating windowにフォーカスが移る。qで離脱
vim.keymap.set('n', 'gp', vim.diagnostic.goto_prev) -- 前のエラー箇所に移動
vim.keymap.set('n', 'gn', vim.diagnostic.goto_next) -- 次のエラー箇所に移動
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist) -- quickfixにエラー箇所一覧を表示
vim.keymap.set('n', 'gl', ":LspRestart<CR>")

-- from: https://github.com/neovim/nvim-lspconfig/blob/master/README.md#suggested-configuration
-- Use LspAttach autocommand to only map the following keys
-- after the language server attaches to the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('UserLspConfig', {}),
  callback = function(ev)
    -- fugitiveバッファにはLSPをアタッチしない
    local bufname = vim.api.nvim_buf_get_name(ev.buf)
    if bufname:match('^fugitive://') then
      vim.schedule(function()
        vim.lsp.buf_detach_client(ev.buf, ev.data.client_id)
      end)
      return
    end

    -- Enable completion triggered by <c-x><c-o>
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Buffer local mappings.
    -- See `:help vim.lsp.*` for documentation on any of the below functions
    local opts = { buffer = ev.buf }
    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
    vim.keymap.set('n', 'gh', vim.lsp.buf.hover, opts) -- floating windowを表示する。その状態で同じキーを押すとfloating windowにフォーカスが移る。qで離脱
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
    -- vim.keymap.set({ 'n', 'i' }, '<C-k>', vim.lsp.buf.signature_help, opts)
    vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts)
    vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts)
    vim.keymap.set('n', '<leader>wl', function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts)
    vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, opts)
    vim.keymap.set('n', 'ge', vim.lsp.buf.rename, opts)
    vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
    vim.keymap.set('n', '<leader>f', function()
      vim.lsp.buf.format { async = true }
    end, opts)
  end,
})

-- }}}

-- blink.cmp {{{
-- C-spaceで補完メニューを表示する
require('blink.cmp').setup({
  cmdline = {
    enabled = true,
    keymap = {
      preset = 'inherit', -- これがないとC-eとかのキーマップを自分で設定できず上書きされてしまう
    },
    completion = { menu = { auto_show = false } },
  },
  --   -- set to 'none' to disable the 'default' preset
  --   preset = 'default',
  --   ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
  --   ['<C-e>'] = { 'hide' },
  --   ['<C-y>'] = { 'select_and_accept' },
  --   ['<Up>'] = { 'select_prev', 'fallback' },
  --   ['<Down>'] = { 'select_next', 'fallback' },
  --   ['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
  --   ['<C-n>'] = { 'select_next', 'fallback_to_mappings' },
  --   ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
  --   ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
  --   ['<Tab>'] = { 'snippet_forward', 'fallback' },
  --   ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
  --   ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
  -- },
})
-- }}}

-- fzf-lua {{{
-- すでに登録されていない場合のみ登録
if not _G.__fzf_lua_ui_select_registered then
  require('fzf-lua').register_ui_select() -- vim.ui.selectをfzf-luaのUIに置き換え
  _G.__fzf_lua_ui_select_registered = true
end
vim.opt.rtp:append('/opt/homebrew/opt/fzf')
vim.keymap.set("n", "<leader>ff", ":FzfLua files<CR>")
vim.keymap.set("n", "<leader>fl", ":FzfLua buffers<CR>") -- 今開いているバッファをファイル名で検索
vim.keymap.set("n", "<leader>fq", ":FzfLua quickfix<CR>")
vim.keymap.set("n", "<leader>fgg", ":lua require('fzf-lua').grep({ cmd = 'rg --hidden --ignore-file ~/.nvim_fzf_ignore -i --line-number --column --color=always' })<CR>") -- Git管理のファイルをcase-insensitiveでgrep
vim.keymap.set("n", "<leader>fgi", ":lua require('fzf-lua').grep({ cmd = 'rg --hidden --ignore-file ~/.nvim_fzf_ignore --line-number --column --color=always' })<CR>") -- Git管理のファイルをcase-sensitiveでgrep
vim.keymap.set("n", "<leader>fgb", ":FzfLua grep_curbuf<CR>") -- 今開いているバッファをgrep
vim.keymap.set("n", "<leader>fga", ":FzfLua grep<CR>") -- すべてのファイルをgrep

local actions = require "fzf-lua.actions"
require'fzf-lua'.setup {
  keymap = {
    -- These override the default tables completely
    -- no need to set to `false` to disable a bind
    -- delete or modify is sufficient
    builtin = {
      -- neovim `:tmap` mappings for the fzf win
      ["<F1>"]        = "toggle-help",
      ["<F2>"]        = "toggle-fullscreen",
      -- Only valid with the 'builtin' previewer
      ["<F3>"]        = "toggle-preview-wrap",
      ["<F4>"]        = "toggle-preview",
      -- Rotate preview clockwise/counter-clockwise
      ["<F5>"]        = "toggle-preview-ccw",
      ["<F6>"]        = "toggle-preview-cw",
      ["<S-down>"]    = "preview-page-down",
      ["<S-up>"]      = "preview-page-up",
      ["<S-left>"]    = "preview-page-reset",
    },
    fzf = {
      -- fzf '--bind=' options
      ["ctrl-z"]      = "abort",
      ["ctrl-u"]      = "unix-line-discard",
      ["ctrl-f"]      = "half-page-down",
      ["ctrl-b"]      = "half-page-up",
      ["ctrl-l"]      = "toggle-all",
      ["ctrl-e"]      = "end-of-line",
      ["ctrl-a"]      = "beginning-of-line",
      -- Only valid with fzf previewers (bat/cat/git/etc)
      ["f3"]          = "toggle-preview-wrap",
      ["f4"]          = "toggle-preview",
      ["shift-down"]  = "preview-page-down",
      ["shift-up"]    = "preview-page-up",
    },
  },
  actions = {
    -- These override the default tables completely
    -- no need to set to `false` to disable an action
    -- delete or modify is sufficient
    files = {
      -- providers that inherit these actions:
      --   files, git_files, git_status, grep, lsp
      --   oldfiles, quickfix, loclist, tags, btags
      --   args
      -- default action opens a single selection
      -- or sends multiple selection to quickfix
      -- replace the default action with the below
      -- to open all files whether single or multiple
      -- ["default"]     = actions.file_edit,
      ["default"]     = actions.file_edit_or_qf,
      ["ctrl-s"]      = actions.file_split,
      ["ctrl-v"]      = actions.file_vsplit,
      ["alt-t"]      = actions.file_tabedit,
      ["ctrl-q"]      = actions.file_sel_to_qf,
      ["alt-l"]       = actions.file_sel_to_ll,
    },
    buffers = {
      -- providers that inherit these actions:
      --   buffers, tabs, lines, blines
      ["default"]     = actions.buf_edit,
      ["ctrl-s"]      = actions.buf_split,
      ["ctrl-v"]      = actions.buf_vsplit,
      ["ctrl-t"]      = actions.buf_tabedit,
    }
  },
  grep = {
    no_esc = true,
  },
}
-- }}}

-- vim-gitgutter {{{
vim.opt.updatetime=100
vim.g.gitgutter_map_keys=0 -- <leader>h*がvim-gitgutterでデフォルトで割り当てられていて邪魔なので無効化
vim.keymap.set('n', '<leader>gn', ':GitGutterNextHunk<CR>')
vim.keymap.set('n', '<leader>gp', ':GitGutterPrevHunk<CR>')
vim.keymap.set('n', '<leader>gq', ':GitGutterQuickFix | copen<CR>')
vim.keymap.set('n', '<leader>gs', ':GitGutterStageHunk<CR>')
vim.keymap.set('n', '<leader>gu', ':GitGutterUndoHunk<CR>')
-- }}}

-- vim-fugitive {{{
vim.keymap.set('n', '<leader>g<CR>', ':15split|0G<CR>') -- サイズを指定してfugitiveを開く0をつけると新しいバッファを開くのではなくそのバッファを開く。
vim.keymap.set('n', '<leader>gd', ':Gdiffsplit<CR>')
vim.keymap.set('n', '<leader>gb', ':G blame<CR>')
vim.api.nvim_create_autocmd("FileType", {
  pattern = "fugitive",
  callback = function(ev)
    vim.keymap.set('n', 's', '<Nop>', { buffer = ev.buf })
    vim.keymap.set('n', 'q', 'gq', { buffer = ev.buf, remap = true })
    vim.wo.winfixheight = true
  end,
})
-- }}}

-- gitlinker {{{
-- すでに設定済みでない場合のみセットアップ
if not _G.__gitlinker_setup_done then
  require('gitlinker').setup({})
  _G.__gitlinker_setup_done = true
end
vim.keymap.set('n', '<leader>go', ':GitLink!<CR>')
vim.keymap.set('v', '<leader>go', ':GitLink!<CR>')
-- }}}

-- gitsigns.nvim {{{
-- trouble.nvimがインストールされていると勝手にtrouble.nvimの設定で開く
vim.keymap.set('n', '<leader>gqa', ':Gitsigns setqflist all<CR>', { desc = 'リポジトリ全体のhunkをquickfixに表示' })
vim.keymap.set('n', '<leader>gqb', ':Gitsigns setqflist<CR>', { desc = 'Gitsigns setqflist buffer' })
-- }}}

-- flatten.nvim {{{
require("flatten").setup()
-- }}}

-- term-edit.nvim {{{
require("term-edit").setup({
    -- Mandatory option:
    -- Set this to a lua pattern that would match the end of your prompt.
    -- Or a table of multiple lua patterns where at least one would match the
    -- end of your prompt at any given time.
    -- For most bash/zsh user this is '%$ '.
    -- For most powershell/fish user this is '> '.
    -- For most windows cmd user this is '>'.
    prompt_end = '%$ ',
    -- How to write lua patterns: https://www.lua.org/pil/20.2.html
})
-- }}}

-- snacks.nvim terminal {{{
package.loaded["snacks"] = nil
require("snacks").setup({
  bigfile = { enabled = true },
  terminal = {
    win = {
      keys = {
        ["<C-q>"] = { "hide", mode = { "n", "t" } },
      },
    },
  },
})
-- 汎用ターミナル
vim.keymap.set('n', '<leader>tt', function()
  Snacks.terminal.toggle(nil, {
    win = { position = "bottom", height = 20 },
    count = 1,
  })
end)
-- Claude Code専用ターミナル
vim.keymap.set('n', '<leader>tc', function()
  Snacks.terminal.toggle("zsh -i -c 'claude --dangerously-skip-permissions'", {
    win = { position = "right", width = 0.5 },
  })
end, { desc = "Claude Code terminal" })
-- <C-q>でターミナルをトグル（ノーマルモード、ターミナルバッファ外から）
vim.keymap.set('n', '<C-q>', function()
  if vim.bo.buftype == 'terminal' then
    Snacks.terminal.toggle(nil, {
      win = { position = "bottom", height = 20 },
      count = 1,
    })
  else
    vim.cmd('q')
  end
end)
-- }}}

-- vim-abolish {{{
vim.keymap.set('n', '<C-g>', ':<C-u>%S/') -- 置換
-- }}}

-- close-buffers.nvim {{{
require('close_buffers').setup({
  filetype_ignore = {},  -- Filetype to ignore when running deletions
  file_glob_ignore = {},  -- File name glob pattern to ignore when running deletions (e.g. '*.md')
  file_regex_ignore = {}, -- File name regex pattern to ignore when running deletions (e.g. '.*[.]md')
  preserve_window_layout = { 'this', 'nameless' },  -- Types of deletion that should preserve the window layout
  next_buffer_cmd = nil,  -- Custom function to retrieve the next buffer when preserving window layout
})
vim.keymap.set('n', 'sq', ':BDelete this<CR>')
-- }}}

-- copilot {{{
vim.keymap.set('n', '<leader>cw', ':CopilotChatToggle<CR>')
vim.keymap.set('n', '<leader>cl', ':CopilotChatReset<CR>')
vim.keymap.set('n', '<leader>cm', ':CopilotChatModels<CR>')
vim.keymap.set('n', '<leader>cq', ':CopilotChatStop<CR>')
-- diffから変更後ファイルパスを抽出し、Copilotのfileコンテキスト形式にしてクリップボードにコピーする関数
local function copy_diff_files_to_clipboard()
  -- バッファの全行を取得
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local file_lines = {}  -- +++ で始まる行からファイルパスを抽出
  for _, line in ipairs(lines) do
    if line:match("^+++") then
      -- "+++ "以降のパスを取得し、さらに "b/" を取り除く
      local filepath = line:gsub("^+++ ", ""):gsub("^b/", "")
      table.insert(file_lines, "#file:" .. filepath)
    end
  end
  -- クリップボードにコピー（システムクリップボードを使用）
  vim.fn.setreg('+', table.concat(file_lines, "\n"))
  print("File paths copied to clipboard!")
end
vim.keymap.set('n', '<leader>dc', copy_diff_files_to_clipboard, { noremap = true, silent = false })
local select = require("CopilotChat.select")
require("CopilotChat").setup {
  model = 'gpt-5',
  selection = function(source)
    return select.visual(source) or select.buffer(source)
  end,
  context = 'buffer',
  system_prompt = '/COPILOT_INSTRUCTIONS 説明は日本語でしてください。',
  -- see config/prompts.lua for implementation
  prompts = {
    Explain = {
      prompt = "/COPILOT_EXPLAIN コードを日本語で説明してください。",
      mapping = '<leader>ce',
      description = "コードの説明",
    },
    Review = {
      prompt = '/COPILOT_REVIEW コードを日本語でレビューしてください。',
      mapping = '<leader>cr',
      description = "コードのレビュー",
    },
    Fix = {
      prompt = "このコードには問題があります。バグを修正したコードを表示してください。説明は日本語でお願いします。",
      mapping = '<leader>cf',
      description = "コードの修正",
    },
    Optimize = {
      prompt = "コードを最適化し、パフォーマンスと可読性を向上させてください。説明は日本語でお願いします。",
      mapping = '<leader>co',
      description = "コードの最適化",
    },
    Docs = {
      prompt = "コードに関するドキュメントコメントを日本語のだ・である・体言止めを使った文体で書いてください。あなたの口調は丁寧語のままでいいです。",
      mapping = '<leader>cd',
      description = "コードのドキュメント作成",
    },
    Tests = {
      prompt = "選択したコードの詳細なユニットテストを書いてください。説明は日本語でお願いします。",
      mapping = '<leader>cu',
      description = "テストコード作成",
    },
    FixDiagnostic = {
      prompt = 'コードの診断結果に従って問題を修正してください。修正内容の説明は日本語でお願いします。',
      mapping = '<leader>cfd',
      description = "コードの診断結果から修正",
      selection = require('CopilotChat.select').diagnostics,
    },
    CommitMessage = {
      prompt = '変更に対するコミットメッセージを日本語でdiffとして記述してください。タイトルは50文字以内にし、メッセージは72文字で改行してください。また、gitcommit code blockの形式にしてください。',
      mapping = '<leader>cc',
      description = "コミットメッセージの作成",
      context = 'git:staged',
    },
  },

  mappings = {
    complete = {
      insert = '<Tab>',
    },
    close = {
      normal = 'q',
      insert = '<C-c>',
    },
    reset = {
      normal = '<C-l>',
      insert = '<C-l>',
    },
    submit_prompt = {
      normal = '<CR>',
      insert = '<C-s>',
    },
    toggle_sticky = {
      normal = 'crr',
    },
    clear_stickies = {
      normal = 'crx',
    },
    accept_diff = {
      normal = '<C-y>',
      insert = '<C-y>',
    },
    jump_to_diff = {
      normal = 'cj',
    },
    quickfix_answers = {
      normal = 'cqa',
    },
    quickfix_diffs = {
      normal = 'cqd',
    },
    yank_diff = {
      normal = 'cy',
      register = '"', -- Default register to use for yanking
    },
    show_diff = {
      normal = 'cd',
      full_diff = false, -- Show full diff instead of unified diff when showing diff window
    },
    show_info = {
      normal = 'ci',
    },
    show_context = {
      normal = 'cc',
    },
    show_help = {
      normal = 'ch',
    },
  },
  contexts = (function()
    -- 動的に生成する、コンテキストでファイルをグルーピングしたコンテキストを生成
    local dynamic_file_group_contexts = {}
    local context_dir = vim.fn.expand("~/copilot_context/")
    -- ディレクトリ内の *.txt ファイルを取得
    local txt_files = vim.fn.glob(context_dir .. "*.txt", true, true)
    if txt_files and #txt_files > 0 then
      for _, txt_filepath in ipairs(txt_files) do
        local context_name = vim.fn.fnamemodify(txt_filepath, ":t:r") -- 例: "point.txt" -> "point"
        dynamic_file_group_contexts[context_name] = {
          resolve = function()
            local ok, lines = pcall(vim.fn.readfile, txt_filepath)
            if not ok then
              return { { content = "Error: Could not read " .. txt_filepath, filename = txt_filepath, filetype = "txt" } }
            end

            local context_items = {}
            for _, filepath in ipairs(lines) do
              if filepath:match("%S") and not filepath:match("^%s*#") then
                local expanded_path = vim.fn.expand(filepath)
                local content = ""
                local file_ok, file_content = pcall(vim.fn.readfile, expanded_path)
                if file_ok then
                  content = table.concat(file_content, "\n")
                else
                  content = "Error: Could not read " .. expanded_path
                end
                table.insert(context_items, {
                  content = content,
                  filename = expanded_path,
                  filetype = vim.fn.fnamemodify(expanded_path, ":e") or "txt",
                })
              end
            end
            return context_items
          end,
        }
      end
    end

    -- gitdiff コンテキスト
    -- #gitdiff:main..feature-branch という形式で引数を渡すと、main と feature-branch の差分を表示する
    local gitdiff_context = {
      gitdiff = {
        resolve = function(args)
          -- argsが文字列でない、またはnilの場合のエラー処理
          if not args or type(args) ~= "string" then
            return {
              {
                content = "Please provide arguments in the format #gitdiff:xxx..yyy (e.g., #gitdiff:main..feature-branch)",
                filename = "gitdiff_error.txt",
                filetype = "txt",
              },
            }
          end

          -- argsを ".." で分割して xxx と yyy を取得
          local xxx, yyy = args:match("^([^%.]+)%.%.([^%.]+)$")
          if not xxx or not yyy then
            return {
              {
                content = "Please provide two arguments separated by '..' (e.g., #gitdiff:main..feature-branch). Received: " .. args,
                filename = "gitdiff_error.txt",
                filetype = "txt",
              },
            }
          end

          -- git diff コマンドを実行
          local diff_command = string.format("git diff %s %s", xxx, yyy)
          local diff_output = vim.fn.system(diff_command)

          -- コマンドの実行結果を確認
          if vim.v.shell_error ~= 0 or diff_output == "" then
            return {
              {
                content = "Error: Could not generate diff for " .. xxx .. " and " .. yyy .. "\n" .. diff_output,
                filename = "gitdiff_error.txt",
                filetype = "txt",
              },
            }
          end

          -- 差分をコンテキストとして返す
          return {
            {
              content = diff_output,
              filename = string.format("git_diff_%s_%s.diff", xxx, yyy),
              filetype = "diff",
            },
          }
        end,
      },
    }

    -- すべてのコンテキストをマージ
    return vim.tbl_extend("force", dynamic_file_group_contexts, gitdiff_context)
  end)(),
}
-- }}}

-- diffview.nvim {{{
vim.keymap.set('n', '<leader>db', ':DiffviewFileHistory --no-merges %<CR>',  { desc = "今開いているバッファの変更履歴を表示" })
vim.keymap.set('n', '<leader>dc', ':DiffviewClose<CR>',  { desc = "今開いているDiffviewを閉じる" })
local diff_view_actions = require("diffview.actions")
require("diffview").setup({
  keymaps = {
    disable_defaults = false, -- Disable the default keymaps
    view = {
      -- The `view` bindings are active in the diff buffers, only when the current
      -- tabpage is a Diffview.
      { "n", "<C-n>", diff_view_actions.select_next_entry, { desc = "Open the diff for the next file" } },
      { "n", "<C-p>", diff_view_actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
    },
    file_panel = {
      { "n", "<C-n>", diff_view_actions.select_next_entry, { desc = "Open the diff for the next file" } },
      { "n", "<C-p>", diff_view_actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
    },
    file_history_panel = {
      { "n", "<C-n>", diff_view_actions.select_next_entry, { desc = "Open the diff for the next file" } },
      { "n", "<C-p>", diff_view_actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
    },
  },
})
-- }}}

-- octo.nvim {{{
vim.keymap.set('n', '<leader>ol', ':Octo search is:pr is:open user-review-requested:@me<CR>a<Del>') -- 自分にレビュー依頼されているPR一覧を表示
vim.keymap.set('n', '<leader>oa', ':Octo pr list<CR>') -- PR一覧を表示
vim.keymap.set('n', '<leader>oc', ':Octo review comments<CR>') -- Pendingのレビューコメント一覧を表示
require"octo".setup({
  picker = "fzf-lua",
  mappings = {
    pull_request = {
      checkout_pr = { lhs = "<localleader>ch", desc = "checkout PR" }, -- デフォルトから変えた
      merge_pr = { lhs = "<localleader>pm", desc = "merge commit PR" },
      squash_and_merge_pr = { lhs = "<localleader>psm", desc = "squash and merge PR" },
      rebase_and_merge_pr = { lhs = "<localleader>prm", desc = "rebase and merge PR" },
      list_commits = { lhs = "<localleader>pc", desc = "list PR commits" },
      list_changed_files = { lhs = "<localleader>pf", desc = "list PR changed files" },
      show_pr_diff = { lhs = "<localleader>pd", desc = "show PR diff" },
      add_reviewer = { lhs = "<localleader>va", desc = "add reviewer" },
      remove_reviewer = { lhs = "<localleader>vd", desc = "remove reviewer request" },
      close_issue = { lhs = "<localleader>ic", desc = "close PR" },
      reopen_issue = { lhs = "<localleader>io", desc = "reopen PR" },
      list_issues = { lhs = "<localleader>il", desc = "list open issues on same repo" },
      reload = { lhs = "<C-r>", desc = "reload PR" },
      open_in_browser = { lhs = "<localleader>go", desc = "open PR in browser" }, -- デフォルトから変えた
      copy_url = { lhs = "<C-y>", desc = "copy url to system clipboard" },
      goto_file = { lhs = "gf", desc = "go to file" },
      add_assignee = { lhs = "<localleader>aa", desc = "add assignee" },
      remove_assignee = { lhs = "<localleader>ad", desc = "remove assignee" },
      create_label = { lhs = "<localleader>lc", desc = "create label" },
      add_label = { lhs = "<localleader>la", desc = "add label" },
      remove_label = { lhs = "<localleader>ld", desc = "remove label" },
      goto_issue = { lhs = "<localleader>gi", desc = "navigate to a local repo issue" },
      add_comment = { lhs = "<localleader>ca", desc = "add comment" },
      delete_comment = { lhs = "<localleader>cd", desc = "delete comment" },
      next_comment = { lhs = "<C-n>", desc = "go to next comment" }, -- デフォルトから変えた
      prev_comment = { lhs = "<C-p>", desc = "go to previous comment" }, -- デフォルトから変えた
      react_hooray = { lhs = "<localleader>rp", desc = "add/remove 🎉 reaction" },
      react_heart = { lhs = "<localleader>rh", desc = "add/remove ❤️ reaction" },
      react_eyes = { lhs = "<localleader>re", desc = "add/remove 👀 reaction" },
      react_thumbs_up = { lhs = "<localleader>r+", desc = "add/remove 👍 reaction" },
      react_thumbs_down = { lhs = "<localleader>r-", desc = "add/remove 👎 reaction" },
      react_rocket = { lhs = "<localleader>rr", desc = "add/remove 🚀 reaction" },
      react_laugh = { lhs = "<localleader>rl", desc = "add/remove 😄 reaction" },
      react_confused = { lhs = "<localleader>rc", desc = "add/remove 😕 reaction" },
      review_start = { lhs = "<localleader>vs", desc = "start a review for the current PR" },
      review_resume = { lhs = "<localleader>vr", desc = "resume a pending review for the current PR" },
      resolve_thread = { lhs = "<localleader>rt", desc = "resolve PR thread" },
      unresolve_thread = { lhs = "<localleader>rT", desc = "unresolve PR thread" },
    },
    review_diff = {
      submit_review = { lhs = "<localleader>vs", desc = "submit review" },
      discard_review = { lhs = "<localleader>vd", desc = "discard review" },
      add_review_comment = { lhs = "<localleader>ca", desc = "add a new review comment", mode = { "n", "x" } },
      add_review_suggestion = { lhs = "<localleader>sa", desc = "add a new review suggestion", mode = { "n", "x" } },
      focus_files = { lhs = "<localleader>e", desc = "move focus to changed file panel" },
      toggle_files = { lhs = "<localleader>t", desc = "hide/show changed files panel" }, -- デフォルトから変えた
      next_thread = { lhs = "]t", desc = "move to next thread" },
      prev_thread = { lhs = "[t", desc = "move to previous thread" },
      select_next_entry = { lhs = "<C-n>", desc = "move to next changed file" }, -- デフォルトから変えた
      select_prev_entry = { lhs = "<C-p>", desc = "move to previous changed file" }, -- デフォルトから変えた
      select_first_entry = { lhs = "[Q", desc = "move to first changed file" },
      select_last_entry = { lhs = "]Q", desc = "move to last changed file" },
      close_review_tab = { lhs = "<C-c>", desc = "close review tab" },
      toggle_viewed = { lhs = "<localleader><space>", desc = "toggle viewer viewed state" },
      goto_file = { lhs = "gf", desc = "go to file" },
    },
  },
})
-- }}}

-- barbar.nvim {{{
vim.keymap.set('n', 'sqb', ':BufferClose<CR>')
vim.keymap.set('n', 'sqa', ':BufferCloseAllButCurrent<CR>')
vim.keymap.set('n', 'sqr', ':BufferCloseBuffersRight<CR>')
vim.keymap.set('n', 'sql', ':BufferCloseBuffersLeft<CR>')
vim.keymap.set('n', 'sn', ':BufferNext<CR>')
vim.keymap.set('n', 'sp', ':BufferPrevious<CR>')
vim.keymap.set('n', 'sbr', ':BufferRestore<CR>')
vim.keymap.set('n', 'sm', ':BufferPick<CR>') -- バッファを選択して開く
require'barbar'.setup {
  -- Enable/disable animations
  animation = false,

  -- Automatically hide the tabline when there are this many buffers left.
  -- Set to any value >=0 to enable.
  auto_hide = true,

  -- Enable/disable current/total tabpages indicator (top right corner)
  tabpages = true,

  -- Enables/disable clickable tabs
  --  - left-click: go to buffer
  --  - middle-click: delete buffer
  clickable = false,

  -- If true, new buffers will be inserted at the start/end of the list.
  -- Default is to insert after current buffer.
  insert_at_end = false,
  insert_at_start = true,

  -- If set, the letters for each buffer in buffer-pick mode will be
  -- assigned based on their name. Otherwise or in case all letters are
  -- already assigned, the behavior is to assign letters in order of
  -- usability (see order below)
  semantic_letters = false,
}
-- }}}

-- nvim-treesitter-context {{{
require'treesitter-context'.setup{
  enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
  multiwindow = true, -- Enable multiwindow support. デフォルトから変えた
  max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
  min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
  line_numbers = true,
  multiline_threshold = 20, -- Maximum number of lines to show for a single context
  trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
  mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
  -- Separator between context and content. Should be a single character string, like '-'.
  -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
  separator = '-', -- デフォルトから変えた
  zindex = 20, -- The Z-index of the context window
  on_attach = nil, -- (fun(buf: integer): boolean) return false to disable attaching
}
-- }}}

-- neoscroll.nvim {{{
require('neoscroll').setup({
  mappings = {                 -- Keys to be mapped to their corresponding default scrolling animation
    '<C-u>', '<C-d>',
    '<C-b>', '<C-f>',
    '<C-y>', '<C-e>',
    'zt', 'zz', 'zb',
  },
  hide_cursor = false,          -- Hide cursor while scrolling デフォルトから変えた
  stop_eof = true,             -- Stop at <EOF> when scrolling downwards
  respect_scrolloff = false,   -- Stop scrolling when the cursor reaches the scrolloff margin of the file
  cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
  duration_multiplier = 0.01,   -- Global duration multiplier デフォルトから変えた
  easing = 'linear',           -- Default easing function
  pre_hook = nil,              -- Function to run before the scrolling animation starts
  post_hook = nil,             -- Function to run after the scrolling animation ends
  performance_mode = false,    -- Disable "Performance Mode" on all buffers.
  ignored_events = {           -- Events ignored while scrolling
      'WinScrolled', 'CursorMoved'
  },
})
-- }}}

-- lualine.nvim {{{
require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'auto',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    always_show_tabline = true,
    globalstatus = true, -- グローバルステータスラインを有効化
    refresh = {
      statusline = 100,
      tabline = 100,
      winbar = 100,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {'filename'},
    lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_y = {'progress', 'selectioncount'},
    lualine_z = {'location', 'tabs',
      -- カレントワーキングディレクトリを表示する
      {
        function()
          return vim.fn.getcwd()
        end,
        icon = '',
      },
    },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
-- }}}

-- codecompanion.nvim {{{
require("codecompanion").setup()
-- }}}

-- bqf.nvim {{{
require('bqf').setup({
  auto_enable = true,
  auto_resize_height = true,
  preview = {
    winblend = 0,
  },
})
-- }}}

-- vim-interestingwords {{{
vim.keymap.set('n', '<leader>k', ':call InterestingWords("n")<CR>', { silent = true })
vim.keymap.set('v', '<leader>k', ':call InterestingWords("v")<CR>', { silent = true })
vim.keymap.set('n', '<leader>K', ':call UncolorAllWords()<CR>', { silent = true })
vim.keymap.set('n', 'n', ':call WordNavigation(1)<CR>', { silent = true })
vim.keymap.set('n', 'N', ':call WordNavigation(0)<CR>', { silent = true })
-- }}}

-- leap.nvim {{{
vim.keymap.set({'n', 'x', 'o'}, '<leader>s', '<Plug>(leap)', { desc = "フォーカスしているバッファを対象にleap.nvimを起動" })
vim.keymap.set('n', '<leader>S', '<Plug>(leap-from-window)', { desc = "他のウィンドウを対象にleap.nvimを起動" })
-- Exclude whitespace and the middle of alphabetic words from preview:
--   foobar[baaz] = quux
--   ^----^^^--^^-^-^--^
--   ^の部分にだけジャンプできるようにする
require('leap').opts.preview_filter =
  function (ch0, ch1, ch2)
    return not (
      ch1:match('%s') or
      ch0:match('%a') and ch1:match('%a') and ch2:match('%a')
    )
  end
require('leap').opts.safe_labels = '' -- 最初の一致への自動ジャンプを無効化
vim.api.nvim_set_hl(0, 'LeapBackdrop', { link = 'Comment' }) -- 検索時に全体をグレーアウトする（Commentと同色）
-- }}}

-- trouble.nvim {{{
require('trouble').setup({
  auto_refresh = false, -- auto refresh when open
  focus = true, -- Focus the window when opened
  modes = {
    lsp_references_split_prev = {
      mode = "lsp_references",
      preview = {
        type = "split",
        relative = "win",
        position = "right",
        size = 0.4,
      },
    },
  },
  keys = {
    ["?"] = "help",
    r = "refresh",
    R = "toggle_refresh",
    q = "close",
    o = "jump_close",
    ["<esc>"] = "cancel",
    ["<cr>"] = "jump",
    ["<2-leftmouse>"] = "jump",
    ["<c-s>"] = "jump_split",
    ["<c-v>"] = "jump_vsplit",
    -- go down to next item (accepts count)
    -- j = "next",
    ["}"] = "next",
    ["<c-n>"] = "next", -- デフォルトから変えた
    -- go up to prev item (accepts count)
    -- k = "prev",
    ["{"] = "prev",
    ["<c-p>"] = "prev", -- デフォルトから変えた
    dd = "delete",
    d = { action = "delete", mode = "v" },
    i = "inspect",
    p = "preview",
    P = "toggle_preview",
    zo = "fold_open",
    zO = "fold_open_recursive",
    zc = "fold_close",
    zC = "fold_close_recursive",
    za = "fold_toggle",
    zA = "fold_toggle_recursive",
    zm = "fold_more",
    zM = "fold_close_all",
    zr = "fold_reduce",
    zR = "fold_open_all",
    zx = "fold_update",
    zX = "fold_update_all",
    zn = "fold_disable",
    zN = "fold_enable",
    zi = "fold_toggle_enable",
    gb = { -- example of a custom action that toggles the active view filter
      action = function(view)
        view:filter({ buf = 0 }, { toggle = true })
      end,
      desc = "Toggle Current Buffer Filter",
    },
    s = false, -- デフォルトを無効化
  },
})
-- require("fzf-lua.config").defaults.actions.files["ctrl-t"] = require("trouble.sources.fzf").actions.open
vim.keymap.set("n", "<leader>dl", "<cmd>Trouble lsp toggle win.position=right win.size=0.3<cr>", { desc = "Trouble LSP ペインを右側に表示" })
vim.keymap.set('n', '<leader>de', '<cmd>Trouble diagnostics toggle<cr>', { desc = "Trouble Diagnostics プレビュー分割なし" })
vim.keymap.set("n", "<leader>ds", "<cmd>Trouble symbols toggle focus=true win.size=0.3<cr>", { desc = "Trouble Symbols" })
-- quickfixが開かれたら自動的にTroubleで開く
vim.api.nvim_create_autocmd("BufRead", {
  callback = function(ev)
    if vim.bo[ev.buf].buftype == "quickfix" then
      vim.schedule(function()
        vim.cmd([[cclose]])
        vim.cmd([[Trouble qflist open]])
      end)
    end
  end,
})

-- }}}

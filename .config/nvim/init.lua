require("plugins")

-- 設定値 {{{

-- クリップボード共有
vim.opt.clipboard:append({ "unnamedplus" }) -- レジスタとクリップボードを共有

-- ファイル
vim.opt.fileencoding = "utf-8" -- エンコーディングをUTF-8に設定
vim.opt.swapfile = false -- スワップファイルを作成しない
vim.opt.helplang = "ja" -- ヘルプファイルの言語は日本語
vim.opt.hidden = true -- バッファを切り替えるときにファイルを保存しなくてもOKに

-- 表示
vim.opt.number = true -- 行番号を表示
vim.opt.wrap = false -- テキストの自動折り返しを無効に

-- インデント
vim.opt.shiftwidth = 4 -- シフト幅を4に設定する
vim.opt.tabstop = 4 -- タブ幅を4に設定する

-- 全角スペース、タブ、空白のハイライト
vim.opt.list = true
vim.opt.listchars='tab:>.,trail:_,extends:>,precedes:<,nbsp:%'

-- }}}

-- キー設定 {{{
vim.g.mapleader = ' '
vim.keymap.set('i', 'jj', '<ESC>')
vim.keymap.set('v', '<C-j><C-j>', '<ESC>')
vim.keymap.set('n', ';', ':')
vim.keymap.set('n', ':', ';')
vim.keymap.set('n', '<leader>h', '^')
vim.keymap.set('v', '<leader>h', '^')
vim.keymap.set('n', '<leader>l', '$')
vim.keymap.set('v', '<leader>l', '$')

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
vim.keymap.set('n', 'sJ', '<C-w>J')
vim.keymap.set('n', 'sK', '<C-w>K')
vim.keymap.set('n', 'sL', '<C-w>L')
vim.keymap.set('n', 'sH', '<C-w>H')
vim.keymap.set('n', 'sr', '<C-w>r')
vim.keymap.set('n', 's=', '<C-w>=')
vim.keymap.set('n', 'sQ', ':<C-u>q<CR>')
vim.keymap.set('n', 'sfQ', ':<C-u>q!<CR>')
vim.keymap.set('n', 'sa', ':<C-u>qa<CR>')

-- nvim-tree.lua {{{
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
local function my_on_attach(bufnr)
  local api = require "nvim-tree.api"

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
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
  vim.keymap.set('n', ' ',     api.marks.toggle,                      opts('Toggle Bookmark'))
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
end

-- pass to setup along with your other options
require("nvim-tree").setup {
  on_attach = my_on_attach,
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
vim.keymap.set('n', '<leader>ff', ':NvimTreeFocus<CR>') -- ファイラを開いてないなら開き、開いているならファイラにカーソルを移す

-- }}}

-- }}}

-- バッファ関連 {{{
vim.keymap.set('n', 'sn', ':<C-u>bn<CR>')
vim.keymap.set('n', 'sp', ':<C-u>bp<CR>')
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
require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all" (the five listed parsers should always be installed)
  ensure_installed = "all",

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  highlight = {
    enable = true,
  },
}

vim.keymap.set('n', '<leader>tt', ':TSPlaygroundToggle<CR>')
vim.keymap.set('n', '<leader>tq', ':TSEditQueryUserAfter highlights')
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
require('mason-lspconfig').setup()
-- :h mason-lspconfig.setup_handlers()
require('mason-lspconfig').setup_handlers {
  function(server_name)
    require('lspconfig')[server_name].setup {}
  end,
}
-- 上のハンドラでセットアップしてるのでいらない可能性あり
-- After setting up mason-lspconfig you may set up servers via lspconfig
-- require("lspconfig").lua_ls.setup {}
-- ...
-- }}}

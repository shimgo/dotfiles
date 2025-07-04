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

-- 表示
vim.opt.number = true -- 行番号を表示
vim.opt.wrap = false -- テキストの自動折り返しを無効に

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

-- Quickfix
vim.keymap.set('n', 'sqq', '<C-w><C-w><C-w>q') -- クイックフィックスを閉じる
vim.keymap.set('n', '<C-n>', ':cn<CR>')
vim.keymap.set('n', '<C-p>', ':cp<CR>')

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
require('mason-lspconfig').setup({
  -- これをtrueにしてても、require('lspconfig').graphql.setup({})を呼び出さないと正しく動作しなかった。
  -- また、trueにした状態で、setupを呼び出すとLSPを二重起動してしまうのでfalseにしておく。
  automatic_enable = false
})
-- LSPごとのセットアップ
-- https://github.com/neovim/nvim-lspconfig/blob/4bc481b6f0c0cf3671fc894debd0e00347089a4e/doc/configs.md
-- masonでインストールしたLSPも個別にsetupを呼び出す必要がある（mason-lspconfigのautomatic_enableをfalseにしてるので）
require('lspconfig').graphql.setup({})
require('lspconfig').gopls.setup({})
require("lspconfig").lua_ls.setup {
  on_init = function(client)
    local path = client.workspace_folders[1].name
    if not vim.loop.fs_stat(path..'/.luarc.json') and not vim.loop.fs_stat(path..'/.luarc.jsonc') then
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
}
require('lspconfig').typos_lsp.setup({
    -- Logging level of the language server. Logs appear in :LspLog. Defaults to error.
    cmd_env = { RUST_LOG = "error" },
    init_options = {
        -- Custom config. Used together with a config file found in the workspace or its parents,
        -- taking precedence for settings declared in both.
        -- Equivalent to the typos `--config` cli argument.
        config = '~/code/typos-lsp/crates/typos-lsp/tests/typos.toml',
        -- How typos are rendered in the editor, can be one of an Error, Warning, Info or Hint.
        -- Defaults to error.
        diagnosticSeverity = "Error"
    }
})

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
      local params = vim.lsp.util.make_range_params()
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
            local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or "utf-16"
            vim.lsp.util.apply_workspace_edit(r.edit, enc)
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
require('blink.cmp').setup({
  cmdline = { enabled = true },
  -- keymapのデフォルト
  -- keymap = {
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

-- toggleterm.nvim {{{
require("toggleterm").setup()
vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm size=20 direction=horizontal name=hoge<CR>')
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
  model = 'claude-3.7-sonnet',
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
vim.keymap.set('n', '<leader>db', ':DiffviewFileHistory %<CR>') -- 今開いているバッファの変更履歴を表示
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
  -- サイドバー分のスペースを空ける
  sidebar_filetypes = {
    NvimTree = true,
  },
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

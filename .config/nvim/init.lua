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
require("nvim-tree").setup()
vim.keymap.set('n', '<leader>ft', ':NvimTreeToggle<CR>')
vim.keymap.set('n', '<leader>fb', ':NvimTreeFindFile<CR>') -- 現在のバッファのファイルを指定した状態でファイラを開く
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

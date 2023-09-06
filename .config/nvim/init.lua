vim.g.mapleader = ' '
vim.keymap.set('i', 'jj', '<ESC>')
vim.keymap.set('v', '<C-j><C-j>', '<ESC>')
vim.keymap.set('n', ';', ':')
vim.keymap.set('n', ':', ';')
vim.keymap.set('n', '<leader>h', '^')
vim.keymap.set('v', '<leader>h', '^')
vim.keymap.set('n', '<leader>l', '$')
vim.keymap.set('v', '<leader>l', '$')

vim.keymap.set('n', '<Leader>ve', '<cmd>e ~/.config/nvim/init.lua<cr>')

-- 設定ファイル再読み込み
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
vim.keymap.set('n', '<leader><CR>', '<cmd>lua ReloadConfig()<CR>')

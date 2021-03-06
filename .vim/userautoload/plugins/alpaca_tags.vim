let g:alpaca_tags#cache_dir = '.git/ctags'
let g:alpaca_tags#config = {
    \    '_' : '-R --sort=yes',
    \    'ruby': '--languages=+Ruby',
    \ }

augroup AlpacaTags
    autocmd!
    if exists(':AlpacaTags') && getftype('.git/ctags') != ""
        autocmd BufWritePost Gemfile AlpacaTagsBundle
        autocmd BufEnter * AlpacaTagsSet
        autocmd BufWritePost * AlpacaTagsUpdate
    endif
augroup END

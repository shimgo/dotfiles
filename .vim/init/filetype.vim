augroup MyAutoCmd
  " vim {{{
  autocmd BufRead,BufNewFile *.vim,*.vimrc* set filetype=vim
  " }}}

  " go {{{
  function! s:config_go()
    packadd vim-goimports
    " 本来ならvim-goimportsの中で定義されているので不要のハズだが動かなかったので再定義。どこかで消されてる？
    autocmd BufWritePre <buffer> call goimports#AutoRun()
    set expandtab!
  endfunction
  autocmd FileType go call s:config_go()
  " }}}

  " graphql {{{
  autocmd BufRead,BufNewFile *.graphql,*.graphqls,*.gql set filetype=graphql
  function! s:config_graphql()
    packadd vim-graphql
  endfunction
  autocmd FileType graphql call s:config_graphql()
  " }}}
augroup END

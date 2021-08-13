augroup MyAutoCmd
  " vim {{{
  autocmd BufRead,BufNewFile *.vim,*.vimrc* set filetype=vim
  " }}}

  " go {{{
  function! s:config_go()
    packadd vim-goimports
    " 本来ならvim-goimportsの中で定義されているので不要のハズだが動かなかったので再定義。どこかで消されてる？
    autocmd BufWritePre <buffer> call goimports#AutoRun()
  endfunction
  autocmd FileType go call s:config_go()
  " }}}
augroup END

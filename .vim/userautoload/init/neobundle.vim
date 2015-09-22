" neobundle settings {{{
if has('vim_starting')
    set nocompatible

    " Install NeoBundle if it hasn't been installed
    if !isdirectory(expand("~/.vim/bundle/neobundle.vim/"))
        echo "install neobundle..."

        " Clone neobundle.vim
        :call system("git clone git://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim")
    endif

    " It is necessary to add runtimepath
    "set runtimepath+=~/.vim/bundle/neobundle.vim/
endif
call neobundle#begin(expand('~/.vim/bundle'))
let g:neobundle_default_git_protocol='https'

NeoBundleFetch 'Shougo/neobundle.vim'

" List pugins to load {{{2

NeoBundle 'thinca/vim-quickrun'
" Display indent depth
NeoBundle 'nathanaelkane/vim-indent-guides'
" Bracket completion
NeoBundle 'cohama/lexima.vim'
NeoBundle 'vim-scripts/dbext.vim'
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/neomru.vim'
NeoBundle 'kana/vim-submode'
" Japanese help
NeoBundle 'vim-jp/vimdoc-ja'
" Vital
NeoBundle 'vim-jp/vital.vim'
" Colorschemes
NeoBundle 'altercation/vim-colors-solarized'

call neobundle#end()
" Check pugins hasn't been installed
NeoBundleCheck

" Required
filetype plugin indent on

" NeoBundle path
if g:is_windows
  let $DOTVIM = expand('~/vimfiles')
else
  let $DOTVIM = expand('~/.vim')
endif
let $VIMBUNDLE = $DOTVIM . '/bundle'
let $NEOBUNDLEPATH = $VIMBUNDLE . '/neobundle.vim'

" bundled function
function! g:bundled(bundle)
  if !isdirectory($VIMBUNDLE)
    return g:false
  endif
  if stridx(&runtimepath, $NEOBUNDLEPATH) == -1
    return g:false
  endif

  if a:bundle ==# 'neobundle.vim'
    return g:true
  else
    return neobundle#is_installed(a:bundle)
  endif
endfunction

function! g:neobundled(bundle)
  return g:bundled(a:bundle) && neobundle#tap(a:bundle)
endfunction



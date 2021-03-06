let g:neobundle#log_filename = $HOME . "/neobundle.log"
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

NeoBundle 'mattn/emmet-vim'
NeoBundle 'thinca/vim-quickrun'
" Display indent depth
NeoBundle 'nathanaelkane/vim-indent-guides'
" Bracket completion
NeoBundle 'cohama/lexima.vim'
NeoBundle 'vim-scripts/dbext.vim'
NeoBundle 'Shougo/vimproc', {
\    'build' : {
\        'windows' : 'make -f make_mingw32.mak',
\        'cygwin' : 'make -f make_cygwin.mak',
\        'mac' : 'make -f make_mac.mak',
\        'unix' : 'make -f make_unix.mak',
\    },
\ }
NeoBundleLazy 'Shougo/vimshell', {
\ 'depends' : 'Shougo/vimproc',
\ 'autoload' : {
\   'commands' : [{ 'name' : 'VimShell', 'complete' : 'customlist,vimshell#complete'},
\                 'VimShellExecute', 'VimShellInteractive',
\                 'VimShellTerminal', 'VimShellPop'],
\   'mappings' : ['<Plug>(vimshell_switch)']
\ }}
NeoBundle 'Shougo/unite.vim'
NeoBundle 'Shougo/vimfiler'
NeoBundle 'Shougo/neomru.vim'
NeoBundle 'kana/vim-submode'
NeoBundle 'itchyny/lightline.vim'
NeoBundle 'tpope/vim-fugitive'
NeoBundle 'scrooloose/syntastic'
" text alignment
NeoBundle 'junegunn/vim-easy-align'
" Japanese help
NeoBundle 'vim-jp/vimdoc-ja'
" Vital
NeoBundle 'vim-jp/vital.vim'
" Colorschemes
NeoBundle 'altercation/vim-colors-solarized'
" Require vim compiled with if_lua(:echo has("lua") return 1).
if has('lua')
    NeoBundle 'Shougo/neocomplete'
else
    echo "If you want to use neocomplete, you need lua."
endif
NeoBundle 'Shougo/neosnippet'
NeoBundle 'Shougo/neosnippet-snippets'
NeoBundle 'tpope/vim-endwise'
NeoBundle 'kmnk/vim-unite-giti'
NeoBundle 'thinca/vim-qfreplace'
NeoBundle 'tmhedberg/matchit'
NeoBundle 'ecomba/vim-ruby-refactoring'
NeoBundleLazy 'alpaca-tc/alpaca_tags', {
    \    'depends': ['Shougo/vimproc'],
    \    'autoload' : {
    \       'commands' : [
    \          { 'name' : 'AlpacaTagsBundle', 'complete': 'customlist,alpaca_tags#complete_source' },
    \          { 'name' : 'AlpacaTagsUpdate', 'complete': 'customlist,alpaca_tags#complete_source' },
    \          'AlpacaTagsSet', 'AlpacaTagsCleanCache', 'AlpacaTagsEnable', 'AlpacaTagsDisable', 'AlpacaTagsKillProcess', 'AlpacaTagsProcessStatus',
    \       ],
    \    }
    \ }
NeoBundleLazy 'majutsushi/tagbar', {
      \ "autload": {
      \   "commands": ["TagbarToggle"],
      \ },
      \ "build": {
      \   "mac": "brew install ctags",
      \ }}
NeoBundle 'tpope/vim-rails', { 'autoload' : {
      \ 'filetypes' : ['haml', 'ruby', 'eruby'] }}
NeoBundleLazy 'basyura/unite-rails', {
      \ 'depends' : 'Shougo/unite.vim',
      \ 'autoload' : {
      \   'unite_sources' : [
      \     'rails/bundle', 'rails/bundled_gem', 'rails/config',
      \     'rails/controller', 'rails/db', 'rails/destroy', 'rails/features',
      \     'rails/gem', 'rails/gemfile', 'rails/generate', 'rails/git', 'rails/helper',
      \     'rails/heroku', 'rails/initializer', 'rails/javascript', 'rails/lib', 'rails/log',
      \     'rails/mailer', 'rails/model', 'rails/rake', 'rails/route', 'rails/schema', 'rails/spec',
      \     'rails/stylesheet', 'rails/view'
      \   ]
      \ }}
NeoBundleLazy 'taka84u9/vim-ref-ri', {
      \ 'depends': ['Shougo/unite.vim', 'thinca/vim-ref'] } 
NeoBundle 'thinca/vim-ref'
NeoBundle 'tpope/vim-obsession'
NeoBundle 'tpope/vim-surround'
NeoBundle 'vim-python/python-syntax'
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
function! Bundled(bundle)
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

function! Neobundled(bundle)
  return Bundled(a:bundle) && neobundle#tap(a:bundle)
endfunction



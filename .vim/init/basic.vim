" debug
" set verbose=9
" set verbosefile=./vim.log

" Set augroup.
augroup MyAutoCmd
    autocmd!
augroup END

if !has('gui_running') && !(has('win32') || has('win64'))
    autocmd MyAutoCmd BufWritePost $MYVIMRC nested source $MYVIMRC
else
    autocmd MyAutoCmd BufWritePost $MYVIMRC source $MYVIMRC |
                \if has('gui_running') | source $MYGVIMRC
    autocmd MyAutoCmd BufWritePost $MYGVIMRC if has('gui_running') | source $MYGVIMRC
endif

" file type detection
filetype on

" syntax highlight
syntax enable

" Open quickfix window when execute grep
autocmd QuickFixCmdPost *grep* cwindow

" fold method
" manual – 自分で範囲選択して折りたたみ
" indent – インデント範囲
" marker – {{{ と }}} で囲まれた範囲
" expr – foldexpr による折りたたみレベル指定
" syntax – 現在の syntax に応じた折りたたみ
set foldmethod=marker

" External grep program
if executable('ag')
    set grepprg=ag\ -a
endif

" completion behavior :h cot
set completeopt=menuone,noinsert,noselect,preview

" Display number of rows
set number

" Don't redraw while executing macros
set lazyredraw

" Enable the mode line
set modeline

" The length of the mode line
set modelines=5

" Vim internal help with the command K
set keywordprg=:help

" Language help
set helplang& helplang=ja

" Ignore case
set ignorecase

" Smart ignore case
set smartcase

" Enable the incremental search
set incsearch

" Emphasize the search pattern
set hlsearch

" Emphasize the matching parenthesis
set showmatch

" Blink on matching brackets
set matchtime=1

" Use tabs instead of spaces
set expandtab

" Show line and column number
set ruler
set rulerformat=%m%r%=%l/%L

" tab spaces
set shiftwidth=4
set tabstop=4

" Blank is inserted only the number of 'shiftwidth'.
set smarttab

" Set command window height to reduce number of 'Press ENTER...' prompts
set cmdheight=2

" Show last command in status line
set showcmd

" History size
set history=10000

" Display long lines on the next line
set nowrap

" Use clipboard
if has('clipboard')
  set clipboard=unnamed
endif

" Swapfile direcroty
set directory=~/.vim/tmp

" Make direcroty when save file
augroup vimrc-auto-mkdir  " {{{
    autocmd!
    autocmd BufWritePre * call s:auto_mkdir(expand('<afile>:p:h'), v:cmdbang)
    function! s:auto_mkdir(dir, force)  " {{{
        if !isdirectory(a:dir) && (a:force ||
            \    input(printf('"%s" does not exist. Create? [y/N]', a:dir)) =~? '^y\%[es]$')
            call mkdir(iconv(a:dir, &encoding, &termencoding), 'p')
        endif
    endfunction  " }}}
augroup END  " }}}

" Tag file direcroty
set tags+=./.git/ctags;

" augroup SetTagsFile
"     autocmd!
"     autocmd FileType php set tags+=$HOME/.vim/tags/cakephp/tags
" augroup END
"
" fzf setting when intalled using HomeBrew
set rtp+=/usr/local/opt/fzf

" Encoding {{{
" Make it normal in UTF-8 in Unix.
set encoding=utf-8

" Select newline character (either or both of CR and LF depending on system) automatically
" Default fileformat.
set fileformat=unix
" Automatic recognition of a new line cord.
set fileformats=unix,dos,mac

set fileencodings=utf-8,iso-2022-jp,cp932,sjis,euc-jp
"}}}

" 全角スペース、タブ、空白のハイライト {{{
"タブ、空白、改行の可視化
set list
set listchars=tab:>.,trail:_,extends:>,precedes:<,nbsp:%

"全角スペースをハイライト表示
function! ZenkakuSpace()
    highlight ZenkakuSpace cterm=reverse ctermfg=DarkMagenta gui=reverse guifg=DarkMagenta
endfunction

" ポップアップ内の色指定
highlight Pmenu ctermbg=235 ctermfg=251
highlight PmenuSel ctermbg=White ctermfg=Black
highlight PmenuSbar ctermbg=DarkGray
highlight PmenuThumb ctermbg=White

if has('syntax')
    augroup ZenkakuSpace
        autocmd!
        autocmd ColorScheme       * call ZenkakuSpace()
        autocmd VimEnter,WinEnter * match ZenkakuSpace /　/
    augroup END
    call ZenkakuSpace()
endif
" }}}


let mapleader = "\<Space>"

" Invalidate compatible for vi
set nocompatible

" one that can be erased by backspace key
set backspace=indent,eol,start

" Invalidate key {{{2
nnoremap s <Nop>
nnoremap Q <Nop>

" Escape {{{2
inoremap jj <ESC>
vnoremap <C-j><C-j> <ESC>
onoremap jj <ESC>

" Editting vimrc {{{2
nnoremap <Leader>ev  :<C-u>edit $MYVIMRC<CR>
nnoremap <Leader>eg  :<C-u>edit $MYGVIMRC<CR>
nnoremap <Leader>eb  :<C-u>edit $USERAUTOLOAD/init/basic.vim<CR>
nnoremap <Leader>ek  :<C-u>edit $USERAUTOLOAD/init/keymap.vim<CR>
nnoremap <Leader>en  :<C-u>edit $USERAUTOLOAD/init/neobundle.vim<CR>
nnoremap <Leader>es  :<C-u>edit $USERAUTOLOAD/init/statusline.vim<CR>
noremap  <Leader>h ^
nnoremap <Leader>vk  :<C-u>help index.txt@ja<CR>
noremap  <Leader>l $

" Load .gvimrc after .vimrc edited at GVim.
nnoremap <silent> <Leader>rv :<C-u>source $MYVIMRC 
\    \| if has('gui_running') 
\    \| source $MYGVIMRC 
\    \| endif <CR>
nnoremap <silent> <Leader>rg :<C-u>source $MYGVIMRC<CR>

" Buffer {{{2
nnoremap sN :<C-u>bn<CR>
nnoremap sP :<C-u>bp<CR>
nnoremap sQ :<C-u>bd<CR>
nnoremap sQf :<C-u>bd!<CR>
nnoremap sb :<C-u>enew<CR>

" Window  {{{2
nnoremap ss :<C-u>split<CR>
nnoremap sv :<C-u>vsplit<CR>
nnoremap sw <C-w>w
nnoremap sj <C-w>j
nnoremap sk <C-w>k
nnoremap sl <C-w>l
nnoremap sh <C-w>h
nnoremap sJ <C-w>J
nnoremap sK <C-w>K
nnoremap sL <C-w>L
nnoremap sH <C-w>H
nnoremap sr <C-w>r
" Resize individual windows equally
nnoremap s= <C-w>=
nnoremap sq :<C-u>q<CR>
nnoremap sq :<C-u>q!<CR>

" Tabpage {{{2
nnoremap sn gt
nnoremap sp gT
nnoremap so <C-w>_<C-w>|
nnoremap st :<C-u>tabnew<CR>
nnoremap sT :<C-u>Unite tab<CR>

" Cursor {{{2
inoremap <C-j> <Down>
inoremap <C-h> <Left>
inoremap <C-k> <Up>
inoremap <C-l> <Right>
nnoremap <silent>j gj
nnoremap <silent>k gk
nnoremap <silent>gj j
nnoremap <silent>gk k

" Plugin key mapping {{{1
"==============================================================================

" vim-submode.vim {{{2
if Has_plugin('vim-submode')
    call submode#enter_with('bufmove', 'n', '', 's>', '<C-w>>')
    call submode#enter_with('bufmove', 'n', '', 's<', '<C-w><')
    call submode#enter_with('bufmove', 'n', '', 's+', '<C-w>+')
    call submode#enter_with('bufmove', 'n', '', 's-', '<C-w>-')
    call submode#map('bufmove', 'n', '', '>', '<C-w>>')
    call submode#map('bufmove', 'n', '', '<', '<C-w><')
    call submode#map('bufmove', 'n', '', '+', '<C-w>+')
    call submode#map('bufmove', 'n', '', '-', '<C-w>-')
endif

" gtags.vim {{{2
nmap <C-q> <C-w><C-w><C-w>q
nmap <C-g> :Gtags -g
nmap <C-l> :Gtags -f %<CR>
nmap <C-j> :Gtags <C-r><C-w><CR>
nmap <C-k> :Gtags -r <C-r><C-w><CR>
nmap <C-n> :cn<CR>
nmap <C-p> :cp<CR>

" unite.vim {{{2
nnoremap [unite]    <Nop>
nmap     <Leader>u [unite]
nnoremap <silent> [unite]a :<C-u>UniteWithCurrentDir buffer file_mru bookmark file<CR>
nnoremap <silent> [unite]c :<C-u>UniteWithBufferDir file file_mru<CR>
nnoremap <silent> [unite]d :<C-u>UniteWithCurrentDir file file_mru<CR>
nnoremap <silent> [unite]b :<C-u>Unite buffer<CR>
nnoremap <silent> [unite]f :<C-u>Unite file<CR>
nnoremap <silent> [unite]g :<C-u>Unite grep<CR>
nnoremap <silent> [unite]m :<C-u>Unite file_mru<CR>


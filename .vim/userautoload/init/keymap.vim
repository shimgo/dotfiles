
let mapleader = "\<Space>"

" Invalidate compatible for vi
set nocompatible

" one that can be erased by backspace key
set backspace=indent,eol,start

" Invalidate key {{{
nnoremap s <Nop>
nnoremap Q <Nop>
" }}}

" Escape {{{
inoremap jj <ESC>
vnoremap <C-j><C-j> <ESC>
onoremap jj <ESC>
" }}}

" Replace {{{
nnoremap <C-h> :<C-u>%s/
" }}}

" Editting vimrc {{{
nnoremap <Leader>ev  :<C-u>edit $MYVIMRC<CR>
nnoremap <Leader>eg  :<C-u>edit $MYGVIMRC<CR>
nnoremap <Leader>eb  :<C-u>edit $USERAUTOLOAD/init/basic.vim<CR>
nnoremap <Leader>ek  :<C-u>edit $USERAUTOLOAD/init/keymap.vim<CR>
nnoremap <Leader>en  :<C-u>edit $USERAUTOLOAD/init/neobundle.vim<CR>
nnoremap <Leader>es  :<C-u>edit $USERAUTOLOAD/init/statusline.vim<CR>
noremap  <Leader>h ^
nnoremap <Leader>vk  :<C-u>help index.txt@ja<CR>
noremap  <Leader>l $
" }}}

" Load .gvimrc after .vimrc edited at GVim.
nnoremap <silent> <Leader>rv :<C-u>source $MYVIMRC 
\    \| if has('gui_running') 
\    \| source $MYGVIMRC 
\    \| endif <CR>
nnoremap <silent> <Leader>rg :<C-u>source $MYGVIMRC<CR>
" }}}

" Window  {{{
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
nnoremap sQ :<C-u>q<CR>
nnoremap sfQ :<C-u>q!<CR>
" }}}

" Buffer {{{
nnoremap sn :<C-u>bn<CR>
nnoremap sp :<C-u>bp<CR>
nnoremap sq :<C-u>Ebd<CR>
nnoremap sfq :<C-u>bd!<CR>
nnoremap sb :<C-u>enew<CR>
" }}}

" Tabpage {{{
nnoremap sN gt
nnoremap sP gT
nnoremap so <C-w>_<C-w>|
nnoremap st :<C-u>tabnew<CR>
nnoremap sT :<C-u>Unite tab<CR>
" }}}

" Cursor {{{
inoremap <C-g><C-h> <Left>
inoremap <C-g><C-l> <Right>
" Move cursor on line of the appearance 
" These have been taken measures for issue of snippet expansion
nnoremap j gj
onoremap j gj
xnoremap j gj
nnoremap k gk
onoremap k gk
xnoremap k gk
" }}}

" Command difinition and key mapping
"==============================================================================
" Close buffer without Closing window
command! Ebd call EBufdelete()
function! EBufdelete()
    let l:currentBufNum = bufnr("%")
    let l:alternateBufNum = bufnr("#")

    if buflisted(l:alternateBufNum)
        buffer #
    else
        bnext
    endif

    if buflisted(l:currentBufNum)
        execute "silent bwipeout".l:currentBufNum
        " bwipeoutに失敗した場合はウインドウ上のバッファを復元
        if bufloaded(l:currentBufNum) != 0
            execute "buffer " . l:currentBufNum
        endif
    endif
endfunction                                        

" Plugin key mapping {{{
"==============================================================================

" vim-submode.vim {{{
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
" }}}

" gtags.vim {{{
nmap <C-q> <C-w><C-w><C-w>q
nmap <C-g> :Gtags -g
nmap <C-l> :Gtags -f %<CR>
nmap <C-j> :Gtags <C-r><C-w><CR>
nmap <C-k> :Gtags -r <C-r><C-w><CR>
nmap <C-n> :cn<CR>
nmap <C-p> :cp<CR>
" }}}

" unite.vim {{{
nnoremap [unite]    <Nop>
nmap     <Leader>u [unite]
nnoremap <silent> [unite]a :<C-u>UniteWithCurrentDir buffer file_mru bookmark file<CR>
nnoremap <silent> [unite]b :<C-u>UniteWithBufferDir file file/new file_mru<CR>
nnoremap <silent> [unite]c :<C-u>UniteWithCurrentDir file file/new file_mru<CR>
nnoremap <silent> [unite]l :<C-u>Unite buffer<CR>
nnoremap <silent> [unite]f :<C-u>Unite file<CR>
nnoremap <silent> [unite]g :<C-u>Unite grep<CR>
nnoremap <silent> [unite]m :<C-u>Unite file_mru<CR>
" }}}

" vimshell {{{
nmap <silent> vs :<C-u>VimShell<CR>
nmap <silent> vp :<C-u>VimShellPop<CR>
" }}}

" }}}

" fugitive.vim {{{
nnoremap [fugitive]    <Nop>
nmap     <Leader>g [fugitive]

" Display git status on new window
nnoremap <silent> [fugitive]s :<C-u>Gstatus<CR>

" Display most recent commits of current buffer also you can specify revision
nnoremap [fugitive]v :<C-u>Gread<Space>

" git add current buffer also you can specify file path
nnoremap [fugitive]a :<C-u>Gwrite<Space>

" git commit
nnoremap [fugitive]c :<C-u>Gcommit<Space>

" git blame
nnoremap <silent> [fugitive]b :<C-u>Gblame<CR>

" Display difference between current buffer and HEAD also you can specify revision
" ex. :Gdiff master
nnoremap [fugitive]d :<C-u>Gdiff<Space>

" git-rm current buffer also you can specify file path
nnoremap [fugitive]r :<C-u>Gremove<Space>

" }}}

" vimfiler.vim {{{
nnoremap [vimfiler] <Nop>
nmap     <Leader>f [vimfiler]

" Open VimFiler like IDE
nnoremap <silent> [vimfiler]b :<C-u>VimFilerBufferDir -split -simple -winwidth=35 -no-quit<CR> 
nnoremap <silent> [vimfiler]c :<C-u>VimFilerCurrentDir -split -simple -winwidth=35 -no-quit<CR> 
" }}}

" vim-easy-align.vim {{{
vmap <Enter> <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)
" }}}


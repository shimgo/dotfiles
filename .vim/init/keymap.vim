let mapleader = "\<Space>"

" swap : ;
nnoremap ; :
nnoremap : ;
vnoremap ; :
vnoremap : ;

" Invalidate compatible for vi
set nocompatible

" one that can be erased by backspace key
set backspace=indent,eol,start

" Invalidate key {{{
nnoremap s <Nop>
nnoremap Q <Nop>
" }}}

" Pretty formatting {{{
nnoremap [pretty]    <Nop>
nmap     <Leader>p [pretty]
nnoremap <silent> [pretty]xml :<C-u>%s/></>\r</g \| filetype indent on \| setf xml \| normal gg=G<CR>
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
noremap  <Leader>h ^
nnoremap <Leader>vk  :<C-u>help index.txt@ja<CR>
noremap  <Leader>l $
" }}}

" Load .gvimrc after .vimrc edited at GVim. {{{
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
nnoremap sa :<C-u>qa<CR>
" }}}

" Buffer {{{
nnoremap sn :<C-u>bn<CR>
nnoremap sp :<C-u>bp<CR>
nnoremap sq :<C-u>Ebd<CR>
nnoremap sfq :<C-u>bd!<CR>
nnoremap sb :<C-u>enew<CR>
" }}}

" Quickfix {{{
nnoremap sc <C-w><C-w><C-w>q
nnoremap <C-n> :cn<CR>
nnoremap <C-p> :cp<CR>
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

" Paste mode {{{
nnoremap tpy  :<C-u>set paste<CR>
nnoremap tpn :<C-u>set nopaste<CR>
" }}}

" Command difinition and key mapping {{{
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
        " recover buffer on window if bwipeout failed
        if bufloaded(l:currentBufNum) != 0
            execute "buffer " . l:currentBufNum
        endif
    endif
endfunction                                        
" }}}
" Plugin key mapping {{{
"==============================================================================

" ultisnips {{{
nnoremap <Leader>es :<C-u>UltiSnipsEdit<space>
" }}}

" gtags.vim {{{
nnoremap <C-g><C-g> :Gtags -g 
nnoremap <C-g><C-l> :Gtags -f %<CR>
nnoremap <C-g><C-d> :Gtags <C-r><C-w><CR>
" Jump reference
nnoremap <C-g><C-r> :Gtags -r <C-r><C-w><CR>
" Jump definition
nnoremap <C-g><C-d> :GtagsCursor<CR>
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


" fugitive.vim {{{
nnoremap [fugitive]    <Nop>
nmap     <Leader>g [fugitive]

" Display git status [-unormal] on new window
nnoremap <silent> [fugitive]<CR> :<C-u>Gstatus<CR>

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

" vim-easy-align.vim {{{
vmap <Enter> <Plug>(EasyAlign)
nmap ga <Plug>(EasyAlign)
" }}}

" neosnippet.vim {{{
imap <C-k>     <Plug>(neosnippet_expand_or_jump)
smap <C-k>     <Plug>(neosnippet_expand_or_jump)
xmap <C-k>     <Plug>(neosnippet_expand_target)

" SuperTab like snippets behavior.
"imap <expr><TAB>
" \ pumvisible() ? "\<C-n>" :
" \ neosnippet#expandable_or_jumpable() ?
" \    "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"">>>>>
smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
    \ "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"

" For conceal markers.
if has('conceal')
  set conceallevel=2 concealcursor=niv
endif
" }}}

" vim-unite-giti {{{
nmap <Leader>gid <SID>(git-diff)
nmap <Leader>giD <SID>(git-diff-cached)
nmap <Leader>gf <SID>(git-fetch-now)
nmap <Leader>gF <SID>(git-fetch)
nmap <Leader>gp <SID>(git-push-now)
nmap <Leader>gP <SID>(git-pull-now)
nmap <Leader>gl <SID>(git-log-line)
nmap <Leader>gL <SID>(git-log)

nmap [unite]gg    <SID>(giti-sources)
nmap [unite]gs    <SID>(git-status)
nmap [unite]gb    <SID>(git-branch)
nmap [unite]gB    <SID>(git-branch_all)
nmap [unite]gc    <SID>(git-config)
nmap [unite]gl    <SID>(git-log)
nmap [unite]gL    <SID>(git-log-this-file)

if globpath(&rtp, 'plugin/giti.vim') != ''
  let g:giti_log_default_line_count = 100
  nnoremap <expr><silent> <SID>(git-diff)        ':<C-u>GitiDiff ' . expand('%:p') . '<CR>'
  nnoremap <expr><silent> <SID>(git-diff-cached) ':<C-u>GitiDiffCached ' . expand('%:p') .  '<CR>'
  nnoremap       <silent> <SID>(git-fetch-now)    :<C-u>GitiFetch<CR>
  nnoremap       <silent> <SID>(git-fetch)        :<C-u>GitiFetch 
  nnoremap <expr><silent> <SID>(git-push-now)    ':<C-u>GitiPushWithSettingUpstream origin ' . giti#branch#current_name() . '<CR>'
  nnoremap       <silent> <SID>(git-push)         :<C-u>GitiPush 
  nnoremap       <silent> <SID>(git-pull-now)     :<C-u>GitiPull<CR>
  nnoremap       <silent> <SID>(git-pull)         :<C-u>GitiPull 
  nnoremap       <silent> <SID>(git-log-line)     :<C-u>GitiLogLine ' . expand('%:p') . '<CR>'
  nnoremap       <silent> <SID>(git-log)          :<C-u>GitiLog ' . expand('%:p') . '<CR>'

  nnoremap <silent> <SID>(giti-sources)   :<C-u>Unite giti<CR>
  nnoremap <silent> <SID>(git-status)     :<C-u>Unite giti/status<CR>
  nnoremap <silent> <SID>(git-branch)     :<C-u>Unite giti/branch<CR>
  nnoremap <silent> <SID>(git-branch_all) :<C-u>Unite giti/branch_all<CR>
  nnoremap <silent> <SID>(git-config)     :<C-u>Unite giti/config<CR>
  nnoremap <silent> <SID>(git-log)        :<C-u>Unite giti/log<CR>

  nnoremap <silent><expr> <SID>(git-log-this-file) ':<C-u>Unite giti/log:' . expand('%:p') . '<CR>'
endif

" apply settings for indivisual commands after following commands
" `:Unite giti/status`, `:Unite giti/branch`, ` :Unite giti/log`
augroup UniteCommand
  autocmd!
  autocmd FileType unite call <SID>unite_settings()
augroup END

function! s:unite_settings()
  for source in unite#get_current_unite().sources
    let source_name = substitute(source.name, '[-/]', '_', 'g')
    if !empty(source_name) && has_key(s:unite_hooks, source_name)
      call s:unite_hooks[source_name]()
    endif
  endfor
endfunction

let s:unite_hooks = {}
function! s:unite_hooks.giti_status() "{{{
  nnoremap <silent><buffer><expr>gM unite#do_action('ammend')
  nnoremap <silent><buffer><expr>gm unite#do_action('commit')
  nnoremap <silent><buffer><expr>ga unite#do_action('stage')
  nnoremap <silent><buffer><expr>gc unite#do_action('checkout')
  nnoremap <silent><buffer><expr>gd unite#do_action('diff')
  nnoremap <silent><buffer><expr>gu unite#do_action('unstage')
endfunction"}}}

function! s:unite_hooks.giti_branch() "{{{
  nnoremap <silent><buffer><expr>d unite#do_action('delete')
  nnoremap <silent><buffer><expr>D unite#do_action('delete_force')
  nnoremap <silent><buffer><expr>rd unite#do_action('delete_remote')
  nnoremap <silent><buffer><expr>rD unite#do_action('delete_remote_force')
endfunction"}}}

function! s:unite_hooks.giti_branch_all() "{{{
  call self.giti_branch()
endfunction"}}}

" vim-ruby-refactoring {{{
:nnoremap <leader>rap  :<C-u>RAddParameter<CR>
:nnoremap <leader>rcpc :<C-u>RConvertPostConditional<CR>
:nnoremap <leader>rel  :<C-u>RExtractLet<CR>
:vnoremap <leader>rec  :<C-u>RExtractConstant<CR>
:vnoremap <leader>relv :<C-u>RExtractLocalVariable<CR>
:nnoremap <leader>rit  :<C-u>RInlineTemp<CR>
:vnoremap <leader>rrlv :<C-u>RRenameLocalVariable<CR>
:vnoremap <leader>rriv :<C-u>RRenameInstanceVariable<CR>
:vnoremap <leader>rem  :<C-u>RExtractMethod<CR>
" }}}

" Qfreplace {{{
:nnoremap <leader>rrp :<C-u>Qfreplace<CR>
" }}}

" tagbar {{{
nnoremap <Leader>t :TagbarToggle<CR>
" }}}

" }}}

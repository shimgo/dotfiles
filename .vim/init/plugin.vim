" vim-lsp {{{
function! s:on_lsp_buffer_enabled() abort
  setlocal omnifunc=lsp#complete
  setlocal signcolumn=yes
  nmap <buffer> gd <plug>(lsp-definition)
  nmap <buffer> gD <plug>(lsp-peek-definition)
  nmap <buffer> gs <plug>(lsp-document-symbol-search)
  nmap <buffer> gS <plug>(lsp-workspace-symbol-search)
  nmap <buffer> gr <plug>(lsp-references)
  nmap <buffer> gi <plug>(lsp-implementation)
  nmap <buffer> gI <plug>(lsp-peek-implementation)
  nmap <buffer> gt <plug>(lsp-type-definition)
  nmap <buffer> gT <plug>(lsp-peek-type-definition)
  nmap <buffer> gh <plug>(lsp-hover)
  nmap <buffer> gp <plug>(lsp-previous-diagnostic)
  nmap <buffer> gn <plug>(lsp-next-diagnostic)
  nmap <buffer> <f2> <plug>(lsp-rename)
  inoremap <buffer> <expr><c-f> lsp#scroll(+4)
  inoremap <buffer> <expr><c-b> lsp#scroll(-4)
  inoremap <expr> <cr> pumvisible() ? "\<c-y>\<cr>" : "\<cr>"
endfunction

augroup lsp_install
  au!
  autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END
command! LspDebug let lsp_log_verbose=1 | let lsp_log_file = expand('~/lsp.log')

let g:lsp_diagnostics_enabled = 1
let g:lsp_diagnostics_echo_cursor = 1
" }}}

" asyncomplete.vim {{{
let g:asyncomplete_auto_popup = 1
let g:asyncomplete_popup_delay = 200
" Tabで補完を起動させる
function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~ '\s'
endfunction
inoremap <silent><expr> <TAB>
  \ pumvisible() ? "\<C-n>" :
  \ <SID>check_back_space() ? "\<TAB>" :
  \ asyncomplete#force_refresh()
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
" }}}

" vim-gitgutter {{{
let g:gitgutter_map_keys = 0
" }}}

" NERDTree {{{
nnoremap [nerdtree] <Nop>
nnoremap <silent> <Leader>fb :<C-u>execute 'NERDTree' expand("%:p:h")<CR>
nnoremap <silent> <Leader>fc :<C-u>execute 'NERDTree' getcwd()<CR>
nnoremap <silent> <Leader>fj :<C-u>NERDTreeToggle<CR>
nnoremap <silent> <Leader>fs :<C-u>NERDTreeToggle<CR>:<C-u>NERDTreeToggle<CR>
" ターミナルで設定しているフォント名と合わせる
set guifont=Hack\ Nerd\ Font\ Mono

" 複数ウィンドウを開いているときにどのウィンドウを開くかを指定する
let s:NERDTreeSelectorKeys = ['a', 's', 'd', 'f', 'g', 'r', 'e', 'w', 'q']
func! MyNERDTreeFileOpen() abort
    let selected = g:NERDTreeFileNode.GetSelected()
    let winKeyMap = {}
    let s:idx = 0
    let textWindowNrs = filter(range(1, winnr('$')), "getwinvar(v:val, '&filetype') !=# 'nerdtree'")

    if len(textWindowNrs) == 1 || selected.path.isDirectory
        call nerdtree#ui_glue#invokeKeyMap("o")
        return
    endif

    for s:winnr in textWindowNrs
        let w:winnr = s:winnr
        let winKeyMap[s:NERDTreeSelectorKeys[s:idx]] = w:winnr
        exe w:winnr . "wincmd w"
        let w:idx = s:idx
        set statusline=%{s:NERDTreeSelectorKeys[w:idx]}
        let s:idx += 1
    endfor

    redrawstatus!

    if selected != {}
        let key = nr2char(getchar())
        exe winKeyMap[key] . "wincmd w"
        exec "e" selected.path.str()
        set statusline=
    endif
endfunc

augroup nerdtree_open | au!
    au FileType nerdtree nnoremap <buffer> o :call MyNERDTreeFileOpen()<CR>
augroup end
" }}}

" vim-goimports {{{
let g:goimports_simplify = 1
" "}}}

" fzf.vim {{{
nnoremap  <Leader>ff :<C-u>Files<CR>
nnoremap  <Leader>fl :<C-u>Buffers<CR>
nnoremap  <Leader>fr :<C-u>History<CR>
nnoremap  <Leader>f; :<C-u>History:<CR>
nnoremap  <Leader>f/ :<C-u>History/<CR>
nnoremap  <Leader>fg :<C-u>Ag<Space>
nnoremap  <Leader><C-f> :<C-u>BLines<CR>
nnoremap  <Leader>fk :<C-u>Maps<CR>
" }}}

" Script variables {{{2
" boolean
let g:true  = 1
let g:false = 0

" Platform {{{2
let g:is_windows = has('win16') || has('win32') || has('win64')
let g:is_cygwin = has('win32unix')
let g:is_mac = !g:is_windows && !g:is_cygwin
      \ && (has('mac') || has('macunix') || has('gui_macvim') ||
      \    (!executable('xdg-open') &&
      \    system('uname') =~? '^darwin'))
let g:is_linux = !g:is_mac && has('unix')

" func s:has_plugin() {{{2
" @params string
" @return bool
function! Has_plugin(name)
  " Check {name} plugin whether there is in the runtime path
  let nosuffix = a:name =~? '\.vim$' ? a:name[:-5] : a:name
  let suffix   = a:name =~? '\.vim$' ? a:name      : a:name . '.vim'
  return &rtp =~# '\c\<' . nosuffix . '\>'
        \   || globpath(&rtp, suffix, 1) != ''
        \   || globpath(&rtp, nosuffix, 1) != ''
        \   || globpath(&rtp, 'autoload/' . suffix, 1) != ''
        \   || globpath(&rtp, 'autoload/' . tolower(suffix), 1) != ''
endfunction

" Rename current buffer
command! -nargs=1 -complete=file Rename f <args>|call delete(expand('#'))

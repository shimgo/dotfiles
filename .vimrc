" Load default runtimepath to be reloadable
set runtimepath&

" Additional runtimepathes
" Required. If you delete this line, runtime! command can't load correctly 
set runtimepath+=~/.vim/userautoload/

let $VIM_INIT = expand('$HOME/.vim/init')

" Basic Settings
source $VIM_INIT/basic.vim

" Keymap
source $VIM_INIT/keymap.vim

" File type
source $VIM_INIT/filetype.vim

" Status Line
source $VIM_INIT/statusline.vim

" Local Settings
if filereadable( $HOME . "/.vimrc_local" )
     source ~/.vimrc_local
endif

set secure

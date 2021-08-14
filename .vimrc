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

" Plugin settings
source $VIM_INIT/plugin.vim

" Local Settings
if filereadable( $HOME . "/.vimrc_local" )
     source ~/.vimrc_local
endif

" Load all plugins now.
" Plugins need to be added to runtimepath before helptags can be generated.
" 最後にしないとNERDTree上のアイコンとgitステータスの表示が崩れる
packloadall

" Load all of the helptags now, after plugins have been loaded.
" All messages and errors will be ignored.
silent! helptags ALL

set secure

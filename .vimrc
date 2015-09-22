" Load default runtimepath to be reloadable
set runtimepath&

" Additional runtimepathes
" Required. If you delete this line, runtime! command can't load correctly 
set runtimepath+=~/.vim/userautoload/

set runtimepath+=~/.vim/bundle/neobundle.vim/

" Global functions
source ~/.vim/userautoload/init/utils.vim

" Encoding settings
source ~/.vim/userautoload/init/encoding.vim

"Load NeoBundle
source ~/.vim/userautoload/init/neobundle.vim

" Basic Settings
source ~/.vim/userautoload/init/basic.vim

" Keymap
source ~/.vim/userautoload/init/keymap.vim

" Status Line
source ~/.vim/userautoload/init/statusline.vim

" Appearcne
source ~/.vim/userautoload/init/appearance.vim

" Load all plugin settings
runtime! plugins/*.vim

set secure

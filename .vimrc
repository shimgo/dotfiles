" Load default runtimepath to be reloadable
set runtimepath&

" Additional runtimepathes
" Required. If you delete this line, runtime! command can't load correctly 
set runtimepath+=~/.vim/userautoload/

set runtimepath+=~/.vim/bundle/neobundle.vim/

" userautoload root
let $USERAUTOLOAD = expand('$HOME/.vim/userautoload')

" Global functions
source $USERAUTOLOAD/init/utils.vim

" Encoding settings
source $USERAUTOLOAD/init/encoding.vim

"Load NeoBundle
source $USERAUTOLOAD/init/neobundle.vim

" Basic Settings
source $USERAUTOLOAD/init/basic.vim

" Keymap
source $USERAUTOLOAD/init/keymap.vim

" Status Line
source $USERAUTOLOAD/init/statusline.vim

" Appearcne
source $USERAUTOLOAD/init/appearance.vim

" Load all plugin settings
runtime! plugins/*.vim

set secure

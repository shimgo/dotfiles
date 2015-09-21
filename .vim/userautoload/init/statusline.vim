" Powerline
if has("python")
    python from powerline.vim import setup as powerline_setup
    python powerline_setup()
    python del powerline_setup
endif

" Show statusline allways 
set laststatus=2

" Show tabline allways 
set showtabline=2

set noshowmode



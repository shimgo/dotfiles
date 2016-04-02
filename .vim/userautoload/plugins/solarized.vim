let g:solarized_termtrans=1
set t_Co=256

colorscheme solarized
"if &t_Co < 256
"  colorscheme default
"else
"  if has('gui_running') && !g:is_windows
"    " For MacVim, only
"    if Has_plugin('solarized.vim')
"      try
"        colorscheme solarized-cui
"      catch
"        colorscheme solarized
"      endtry
"    endif
"  else
"    " Vim for CUI
"    if Has_plugin('solarized.vim')
"      try
"        colorscheme solarized-cui
"      catch
"        colorscheme solarized
"      endtry
"   else
"      if g:is_windows
"        colorscheme default
"      else
"        colorscheme desert
"      endif
"    endif
"  endif
"endif

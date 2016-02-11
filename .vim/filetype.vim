augroup filetypedetect
    au BufRead,BufNewFile *.rb setfiletype ruby
    au BufRead,BufNewFile *.yml setfiletype yaml
    au BufRead,BufNewFile *.php setfiletype php
augroup END

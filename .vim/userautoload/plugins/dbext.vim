if g:neobundled('dbext.vim')
  let dbext_default_profile=""
  let dbext_default_type="MYSQL"
  let dbext_default_user="root"
  let dbext_default_passwd="password"
  " To change dbname: :DBSetOption dbname=mydb 
  let dbext_default_dbname="mydb"
  let dbext_default_host="localhost"
  let dbext_default_buffer_lines=20
  call neobundle#untap()
endif

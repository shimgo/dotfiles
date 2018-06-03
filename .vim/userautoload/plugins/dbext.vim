if Neobundled('dbext.vim')
  let dbext_default_profile=""
  let dbext_default_type="MYSQL"
  let dbext_default_user="root"
  let dbext_default_passwd="password"
  " To change dbname: :DBSetOption dbname=mydb 
  let dbext_default_dbname="mydb"
  let dbext_default_host="localhost"
  let dbext_default_buffer_lines=20
  " To change profile: :DBSetOption profile=sample_local
  let g:dbext_default_profile_sample_local='type=MYSQL:user=root:passwd=:dbname=:host=localhost'
  call neobundle#untap()
endif

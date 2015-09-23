if Has_plugin("lexima.vim")
    call lexima#add_rule({'at': '\%#.*[-0-9a-zA-Z_,:]', 'char': '{', 'input': '{'})
    inoremap < <><LEFT>
endif



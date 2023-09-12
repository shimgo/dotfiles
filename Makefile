ALL_DOTFILES := $(wildcard .*)
EXCLUDES     := . .. .DS_Store .git .gitignore .gitmodules .config
ADDITIONAL   := .config/gh/config.yml .config/nvim/init.lua .config/nvim/lua/plugins.lua
TARGETS      := $(filter-out $(EXCLUDES), $(ALL_DOTFILES)) $(ADDITIONAL)

list: ## Show dotfiles to be processed
	@echo $(TARGETS)

deploy: ## Create symlinks to $HOME
	@$(foreach val, $(TARGETS), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)

clean: ## Remove symlinks in $HOME
	@$(foreach val, $(TARGETS), rm -vrf $(HOME)/$(val);)

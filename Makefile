ALL_DOTFILES := $(wildcard .*)
EXCLUDES     := . .. .DS_Store .git .gitignore .gitmodules .config .claude
ADDITIONAL   := .config/gh/config.yml .config/nvim/init.lua .config/nvim/lua/plugins.lua
CLAUDE_FILES := $(shell find .claude -mindepth 1 -maxdepth 1 -not -name '.DS_Store')
TARGETS      := $(filter-out $(EXCLUDES), $(ALL_DOTFILES)) $(ADDITIONAL) $(CLAUDE_FILES)

list: ## Show dotfiles to be processed
	@echo $(TARGETS)

deploy: ## Create symlinks to $HOME
	@mkdir -p $(HOME)/.config/gh $(HOME)/.config/nvim/lua $(HOME)/.claude
	@$(foreach val, $(TARGETS), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)

clean: ## Remove symlinks in $HOME
	@$(foreach val, $(TARGETS), rm -vrf $(HOME)/$(val);)

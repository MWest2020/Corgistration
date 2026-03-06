.PHONY: install uninstall test lint help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install: ## Install corgistration scripts and K9s plugin entries
	@bash install.sh
	@echo ""
	@echo "Verification steps:"
	@echo "  1. Check scripts are present: ls ~/.local/bin/corgistration.sh"
	@echo "  2. Check K9s plugin:          grep corgi-pod ~/.config/k9s/plugins.yaml"
	@echo "  3. Restart K9s and press Shift-A on any Pod/Deployment/Service"

uninstall: ## Remove corgistration scripts and K9s plugin entries
	@bash uninstall.sh

test: ## Run smoke tests
	@bash test/smoke.sh

lint: ## Check scripts with shellcheck (requires shellcheck)
	@command -v shellcheck >/dev/null || { echo "shellcheck not found — install: https://github.com/koalaman/shellcheck#installing"; exit 1; }
	@shellcheck scripts/*.sh install.sh uninstall.sh test/smoke.sh
	@echo "shellcheck: all scripts OK"

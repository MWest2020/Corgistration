.PHONY: build install uninstall test lint help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

build: ## Build the corgi binary to ./bin/corgi
	@mkdir -p bin
	@go build -ldflags "-X main.version=$$(git describe --tags --always 2>/dev/null || echo dev) -X main.commit=$$(git rev-parse --short HEAD 2>/dev/null || echo none)" -o bin/corgi ./cmd/corgi/
	@echo "  built → bin/corgi"

install: ## Install corgistration (add DEPS=1 to auto-install prerequisites)
	@bash install.sh $(if $(DEPS),--install-deps,)
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
	@shellcheck scripts/*.sh install.sh uninstall.sh get.sh uninstall-remote.sh test/smoke.sh
	@echo "shellcheck: all scripts OK"

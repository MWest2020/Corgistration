## Why

The shell script entry point (`corgistration.sh`) works but requires the user to be inside K9s to trigger it. There is no standalone experience. A Go CLI binary called `corgi` makes the tool a first-class citizen of the terminal: users invoke it directly, get an interactive resource picker when they want one, and pass arguments when they don't. A compiled binary also unlocks proper packaging — apt, dnf, Homebrew, GitHub Releases — without requiring bash, yq, or any runtime on the target machine beyond the binary itself.

## What Changes

- New Go module at repo root (`go.mod`, `cmd/corgi/main.go`, `internal/`)
- `corgi` binary replaces `corgistration.sh` as the primary entry point
- Interactive bubbletea TUI picker: `corgi` with no args lists all Pods, Deployments, and Services across namespaces; user selects one and the diagnostic flow fires
- Direct invocation mode: `corgi <kind> <name> <namespace>` (used by K9s plugin and power users)
- Flags: `--namespace / -n`, `--context`, `--version`
- Parallel context collection via goroutines replaces background subshells in `collect.sh`; `render.sh`, `orchestrate.sh`, `claude-invoke.sh` remain as-is and are still called by the binary
- GitHub Actions release pipeline: matrix build for linux/amd64, linux/arm64, darwin/amd64, darwin/arm64; binaries attached to tags
- `get.sh` updated to detect platform and download the binary instead of copying shell scripts
- K9s plugin updated to call `corgi` instead of `corgistration.sh`

## Capabilities

### New Capabilities
- `corgi-cli`: cobra-based CLI entrypoint — argument parsing, flags, version, help
- `resource-picker`: bubbletea interactive TUI for listing and selecting K8s resources
- `context-collector-go`: parallel context collection via goroutines using client-go for listing and kubectl exec for logs/yaml/describe
- `release-pipeline`: GitHub Actions matrix build and release workflow

### Modified Capabilities
- `k9s-plugin`: plugin command updated from `corgistration.sh` to `corgi`

## Impact

- New runtime dependency: Go 1.22+ (build-time only; binary ships statically linked)
- New Go deps: cobra, bubbletea, lipgloss, client-go
- `corgistration.sh` retained for backwards compatibility but superseded
- `get.sh` installer logic changes from script-copy to binary-download
- K9s plugin YAML updated

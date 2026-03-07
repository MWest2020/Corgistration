## 1. Go Module Setup

- [ ] 1.1 Run `go mod init github.com/MWest2020/Corgistration` at repo root
- [ ] 1.2 Create directory layout: `cmd/corgi/`, `internal/collector/`, `internal/picker/`, `internal/tmux/`
- [ ] 1.3 Add dependencies: `go get github.com/spf13/cobra github.com/charmbracelet/bubbletea github.com/charmbracelet/lipgloss k8s.io/client-go`
- [ ] 1.4 Add `version` and `commit` variables in `cmd/corgi/main.go` for ldflags injection

## 2. CLI Entrypoint (cobra)

- [ ] 2.1 Create root cobra command in `cmd/corgi/main.go` with `--namespace / -n`, `--context`, `--version` flags
- [ ] 2.2 Implement direct invocation mode: if 3 positional args provided, validate kind/name/namespace and proceed to collect+launch
- [ ] 2.3 Implement no-arg mode: if no positional args, launch the bubbletea picker
- [ ] 2.4 Block Secret kind: return error with message "Secret resources are excluded to prevent credential exposure", exit 2
- [ ] 2.5 Wire `--version` to print `corgi vX.Y.Z (commit <sha>)` and exit 0
- [ ] 2.6 Detect non-TTY in no-arg mode: if `os.Stdin` is not a TTY, print usage hint and exit 1

## 3. Context Collector (Go)

- [ ] 3.1 Create `internal/collector/collect.go` with `CollectContext(kind, name, namespace, kubeContext string, timeout time.Duration) (string, error)` signature
- [ ] 3.2 Implement parallel collection: use `sync.WaitGroup` + three goroutines for YAML manifest (`kubectl get -o yaml`), events (`kubectl describe`), logs (`kubectl logs`, Pod only)
- [ ] 3.3 Wrap each goroutine's `exec.Command` with `context.WithTimeout` (default 10s)
- [ ] 3.4 On per-goroutine failure: capture stderr and write error text into that section instead of returning early
- [ ] 3.5 Assemble structured output file with `=== YAML MANIFEST ===`, `=== EVENTS ===`, `=== LOGS ===` headers
- [ ] 3.6 Write output to `os.CreateTemp("", "corgistration-*.txt")` and return the path
- [ ] 3.7 Return error immediately (without any kubectl calls) when `strings.EqualFold(kind, "secret")`
- [ ] 3.8 Pass `--context` flag through to all kubectl calls when set

## 4. Resource Picker (bubbletea)

- [ ] 4.1 Create `internal/picker/model.go` with bubbletea `Model` struct holding resource list, cursor, filter string, loading state
- [ ] 4.2 Implement `Init()`: return a `tea.Cmd` that fetches Pods, Deployments, Services from cluster via client-go using a goroutine
- [ ] 4.3 Build client-go config from kubeconfig: respect `--context` override via `clientcmd.BuildConfigFromFlags`
- [ ] 4.4 Fetch Pods, Deployments, Services concurrently; send results as a `tea.Msg` when done
- [ ] 4.5 Implement `Update()`: handle arrow/j/k navigation, Enter to select, q/Ctrl-C to quit, `/` to toggle filter input
- [ ] 4.6 Implement `View()`: render list rows with lipgloss — Pods green, Deployments cyan, Services yellow; selected row highlighted; filter input shown when active
- [ ] 4.7 Add Pod status indicators: green dot (Running/Ready), yellow (Pending), red (CrashLoopBackOff/Failed/Error)
- [ ] 4.8 Show spinner + "Fetching resources…" while API call is in flight using `github.com/charmbracelet/bubbles/spinner`
- [ ] 4.9 Return selected resource (kind, name, namespace) from `tea.Program.Run()` result for caller to use

## 5. tmux Orchestration (Go wrapper)

- [ ] 5.1 Create `internal/tmux/launch.go` with `Launch(contextFile, kind, name, namespace string) error`
- [ ] 5.2 Locate shell scripts: check `~/.local/bin/` first, then `$PATH`, error with actionable message if not found
- [ ] 5.3 Call `orchestrate.sh` via `exec.Command` with quoted args, inheriting stdin/stdout/stderr so tmux attach works correctly
- [ ] 5.4 Detect if `tmux` is on PATH; return descriptive error if missing

## 6. GitHub Actions Release Pipeline

- [ ] 6.1 Create `.github/workflows/release.yml` triggered on `push: tags: ['v*']`
- [ ] 6.2 Add build matrix: `{os: linux, arch: amd64}`, `{os: linux, arch: arm64}`, `{os: darwin, arch: amd64}`, `{os: darwin, arch: arm64}`
- [ ] 6.3 Each matrix step: `CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -ldflags="-s -w -X main.version=$TAG -X main.commit=$SHA" -o corgi-$os-$arch ./cmd/corgi`
- [ ] 6.4 Generate `checksums.txt` with `sha256sum corgi-*` after all builds
- [ ] 6.5 Create GitHub Release using `softprops/action-gh-release` and attach all binaries + `checksums.txt`
- [ ] 6.6 Add a separate `.github/workflows/ci.yml` triggered on push/PR to main: `go build`, `go vet`, `go test ./...`

## 7. Update get.sh for Binary Download

- [ ] 7.1 Add OS/arch detection: map `uname -s` → `linux`/`darwin`; map `uname -m` → `amd64` (x86_64) / `arm64` (arm64/aarch64)
- [ ] 7.2 Fetch latest release tag from GitHub API: `curl -fsSL https://api.github.com/repos/MWest2020/Corgistration/releases/latest | grep tag_name`
- [ ] 7.3 Download binary: `curl -fsSL .../corgi-$os-$arch -o ~/.local/bin/corgi`
- [ ] 7.4 Download `checksums.txt` and verify SHA-256 with `sha256sum -c` (Linux) or `shasum -a 256 -c` (macOS); abort on mismatch
- [ ] 7.5 `chmod +x ~/.local/bin/corgi`
- [ ] 7.6 Keep shell script download section for `render.sh`, `orchestrate.sh`, `claude-invoke.sh`, `lib.sh`, `corgi.txt` — still needed alongside the binary

## 8. Update K9s Plugin

- [ ] 8.1 Update `k9s/plugins.yaml`: change all three plugin commands from `corgistration.sh Pod/Deployment/Service $NAME $NAMESPACE` to `corgi Pod/Deployment/Service $NAME $NAMESPACE`
- [ ] 8.2 Update `install.sh` and `get.sh` install steps to reflect the new command name in the plugins.yaml merge

## 9. Makefile + README

- [ ] 9.1 Add `make build` target: `go build -o corgi ./cmd/corgi`
- [ ] 9.2 Add `make test-go` target: `go test ./...`
- [ ] 9.3 Update `make lint` to include `go vet ./...`
- [ ] 9.4 Update README: replace K9s-first install story with `corgi` standalone usage as the primary path; K9s plugin becomes an optional integration section
- [ ] 9.5 Add `corgi` usage examples to README: no-arg picker, direct invocation, flags

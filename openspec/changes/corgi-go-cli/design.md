## Context

Corgistration currently works as a set of shell scripts triggered from K9s. The entry point (`corgistration.sh`) is invisible as a standalone tool — it requires K9s, and there's no interactive experience without it. The shell approach also limits distribution: users need bash, yq, and the scripts on their PATH, which complicates packaging.

A Go binary solves both problems: it is a first-class CLI tool that works without K9s, and it compiles to a single static binary that is trivial to distribute via GitHub Releases, Homebrew, apt, or dnf.

The existing shell scripts (`render.sh`, `orchestrate.sh`, `claude-invoke.sh`) are kept as-is. The binary replaces only the entry point layer and context collection layer.

## Goals / Non-Goals

**Goals:**
- `corgi` works standalone — no K9s required
- Interactive picker for users who don't know the resource name
- Direct invocation `corgi <kind> <name> <ns>` for K9s plugin and scripting
- Single static binary with no runtime deps on target machine
- GitHub Actions builds + releases for all four target platforms
- `get.sh` updated to download binary rather than copy scripts

**Non-Goals:**
- Replacing `render.sh` or `claude-invoke.sh` with Go (deferred — shell scripts are fine for now)
- Windows support in v1
- Replacing `tmux` as the split layout mechanism
- Building a full TUI diagnostic view inside the binary (tmux + shell scripts handle that)

## Decisions

### D1: Cobra for CLI, bubbletea + lipgloss for TUI
**Decision**: `github.com/spf13/cobra` for CLI structure; `github.com/charmbracelet/bubbletea` + `github.com/charmbracelet/lipgloss` for the picker.
**Rationale**: Cobra is the de-facto standard Go CLI library (kubectl, helm, and most CNCF tools use it). The Charm stack (bubbletea/lipgloss) is purpose-built for terminal UIs in Go, has excellent documentation, and is actively maintained. Lipgloss handles color/styling safely, including ANSI-off for non-TTY environments.
**Alternative**: `urfave/cli` — simpler but less feature-rich. `tview` — heavier and harder to style.

### D2: client-go for resource listing, kubectl exec for collection
**Decision**: Use `k8s.io/client-go` for the picker's resource list (Pods, Deployments, Services). Continue shelling out to `kubectl` for YAML/logs/describe collection.
**Rationale**: client-go gives a clean Go API for listing and watching resources — exactly what the picker needs. For collection, `kubectl get -o yaml` and `kubectl logs` with their full flag sets are simpler to call as subprocesses than to replicate with raw client-go API calls. The hybrid approach minimises scope while still replacing the performance-critical path (parallel shell subshells → goroutines).
**Alternative**: Full client-go for everything — more correct but significantly more code for log streaming.

### D3: Shell out to existing scripts for orchestration
**Decision**: The binary calls `orchestrate.sh` (and by extension `render.sh` and `claude-invoke.sh`) via `exec.Command` after writing the context file.
**Rationale**: The orchestration logic in shell is already tested and working. Rewriting it in Go adds no user-visible value right now. The boundary is clean: Go owns resource listing, context collection, and CLI UX; shell owns tmux layout and rendering.
**Risk**: Users must still have the shell scripts on PATH (installed by `get.sh`). This is acceptable for v1.

### D4: Version injected via ldflags at build time
**Decision**: Version and commit SHA baked in at build via `-ldflags "-X main.version=... -X main.commit=..."`.
**Rationale**: Standard Go practice. No version files to keep in sync. Release workflow sets the values automatically from the git tag.

### D5: CGO_ENABLED=0 for fully static binaries
**Decision**: All release builds use `CGO_ENABLED=0`.
**Rationale**: Eliminates glibc dependency. Binary runs on any Linux regardless of distro version. Essential for reliable `curl | bash` installs across heterogeneous environments.

### D6: get.sh detects platform, downloads binary, verifies checksum
**Decision**: Rewrite the download section of `get.sh` to use the GitHub Releases API (`/releases/latest`), detect `$(uname -s)` + `$(uname -m)`, download the matching binary, and verify SHA-256 against `checksums.txt`.
**Rationale**: Checksum verification is a minimal supply-chain control. Fail-fast if the download is corrupt or tampered.
**Risk**: Users need `sha256sum` (Linux) or `shasum -a 256` (macOS) — both are universally present.

## Risks / Trade-offs

- **client-go dependency size** → Go module cache grows; binary size increases ~15–20 MB. Acceptable for a CLI tool. Mitigated by `-ldflags="-s -w"` stripping debug symbols.
- **Picker requires a real TTY** → `corgi` in no-arg mode will fail in non-interactive contexts (CI, pipes). Mitigation: detect `isatty` and print a usage hint if not a TTY.
- **Shell scripts still required alongside binary** → `get.sh` must install both the binary and the shell scripts. This is confusing UX. Mitigation: document clearly; full Go replacement of shell scripts is the v2 target.
- **GitHub Actions secrets for releases** → release workflow needs `GITHUB_TOKEN` (automatically provided by Actions) for creating releases. No additional secrets required.

## Open Questions

- Should the picker default to all namespaces or the current-context namespace? (Leaning: current-context namespace, with `--all-namespaces / -A` flag to override.)
- Target Go version: 1.22 (current stable) or pin to 1.21 for wider compatibility? (Leaning: 1.22 — range-over-func is useful and 1.21 is still supported.)
- Homebrew tap: separate repo (`MWest2020/homebrew-corgistration`) or wait until there are more tools? (Deferred to post-release.)

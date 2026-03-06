## 1. Repository & Project Structure

- [x] 1.1 Create top-level directory layout: `scripts/`, `install.sh`, `uninstall.sh`, `README.md`
- [x] 1.2 Create `scripts/corgistration.sh` as the main entry-point stub (accepts kind, name, namespace args)
- [x] 1.3 Add a `scripts/lib.sh` with shared helpers: `require_cmd`, `corgi_log`, and ANSI color variables
- [x] 1.4 Add prerequisite check in entry-point: verify `tmux`, `kubectl`, `claude` are on PATH; print actionable error and exit 1 if any are missing

## 2. K9s Plugin Configuration

- [x] 2.1 Create `k9s/plugins.yaml` template with plugin entries for Pod, Deployment, and Service resources using default hotkey `shift-a`
- [x] 2.2 Write `install.sh`: back up existing `~/.config/k9s/plugins.yaml` to `.corgi-bak`, then merge corgistration entries (yq or awk-based merge to preserve existing plugins)
- [x] 2.3 Write `uninstall.sh`: remove corgistration plugin entries from `plugins.yaml` and restore from backup if present; remove scripts from `~/.local/bin/`
- [x] 2.4 Add idempotency check in `install.sh`: skip merge if corgistration entries already present
- [x] 2.5 Verify `install.sh` copies entry-point and lib scripts to `~/.local/bin/` with `chmod +x`

## 3. Context Collector

- [x] 3.1 Create `scripts/collect.sh` that accepts `kind`, `name`, `namespace` and writes to a `mktemp` temp file
- [x] 3.2 Implement parallel collection using background subshells (`&`) with `wait`: run `kubectl get -o yaml`, `kubectl describe` (events), and `kubectl logs` (Pods only) concurrently
- [x] 3.3 Add `--request-timeout=10s` to all kubectl calls
- [x] 3.4 Write each section to the temp file with labeled headers (`=== YAML MANIFEST ===`, `=== EVENTS ===`, `=== LOGS ===`)
- [x] 3.5 Implement per-section error capture: if a kubectl call fails, write the error message into that section rather than aborting
- [x] 3.6 Add resource-type gate: skip log collection for Deployment and Service; include an empty `=== LOGS ===` section with a note
- [x] 3.7 Add Secret resource guard: if `kind=Secret`, print warning to stderr and exit 2 without collecting anything
- [x] 3.8 Print the temp file path to stdout so the caller (entry-point) can forward it

## 4. TUI Renderer

- [x] 4.1 Create `scripts/render.sh` that reads the structured temp file and streams colored output to stdout
- [x] 4.2 Render section headers (`=== ... ===`) in bold cyan using ANSI escape codes
- [x] 4.3 Pipe the YAML MANIFEST section through `bat --language=yaml --color=always` if available; fall back to plain with a one-line notice
- [x] 4.4 Colorize LOGS section by line severity: ERROR/FATAL → red, WARN/WARNING → yellow, other → default
- [x] 4.5 Colorize EVENTS section: lines starting with `Warning` → yellow with `! ` prefix; lines starting with `Normal` → dim
- [x] 4.6 Detect terminal height (`tput lines`); if rendered output exceeds it, pipe through `less -R`
- [x] 4.7 Write a smoke test: run `render.sh` against a fixture context file and assert ANSI codes are present in output

## 5. tmux Orchestrator

- [x] 5.1 Create `scripts/orchestrate.sh` that accepts the context file path and resource identity
- [x] 5.2 Implement session check: if `tmux has-session -t corgistration` succeeds, reuse it; otherwise create a new detached session
- [x] 5.3 On new session: create a horizontal split with left pane at 55% width
- [x] 5.4 Send `render.sh <context-file>` to the left pane via `tmux send-keys`
- [x] 5.5 Send `claude-invoke.sh <context-file> <kind> <name> <namespace>` to the right pane via `tmux send-keys`
- [x] 5.6 Attach to the session (or switch client if already inside tmux) so the user lands in the layout
- [x] 5.7 Validate that left pane crash/exit does not kill the session (set `remain-on-exit on` for left pane)

## 6. Claude Invoker

- [x] 6.1 Create `scripts/claude-invoke.sh` that accepts context file path, kind, name, namespace
- [x] 6.2 Compose the system prompt string instructing Claude to act as a Kubernetes diagnostic expert (identify problem, explain root cause, suggest fix)
- [x] 6.3 Compose the initial user message including resource identity header and full context file contents
- [x] 6.4 Implement truncation: if context file exceeds 500 lines, truncate logs to last 100 lines and events to last 20 entries; prepend a truncation notice
- [x] 6.5 Check `claude --version` output; warn if below a known-good version (document minimum version in README)
- [x] 6.6 Invoke `claude` with the composed prompt and drop into interactive mode (determine correct flag — `--print` + stdin or direct arg — based on installed claude CLI version)

## 7. Integration & Install Validation

- [x] 7.1 Write an end-to-end smoke test script (`test/smoke.sh`) that: fakes kubectl with fixture outputs, runs `corgistration.sh Pod test-pod default`, and asserts a tmux session named `corgistration` is created with two panes
- [x] 7.2 Add a `make install` target (or equivalent) that runs `install.sh` and prints verification steps
- [x] 7.3 Write `README.md`: prerequisites, install steps, hotkey customization, uninstall, known limitations
- [x] 7.4 Add shell quoting audit: review all scripts for unquoted variable expansions that could enable shell injection via resource name/namespace
- [x] 7.5 Verify idempotent install: run `install.sh` twice on a machine with existing K9s plugins and confirm no duplication or corruption

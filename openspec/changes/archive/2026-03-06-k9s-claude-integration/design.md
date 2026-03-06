## Context

Kubernetes operators using K9s as their primary cluster browser currently have no integrated path from "I see something wrong" to "here is the diagnosis." The typical workflow is: spot an issue in K9s → manually run kubectl commands in a separate terminal → copy-paste output into an AI tool → get a diagnosis → switch back to act. This involves 4–6 context switches per incident.

Corgistration is a pure shell + tmux integration that lives entirely in user-space. No cluster components, no sidecars, no admission webhooks. It hooks into K9s's existing plugin system and tmux's split-pane model, then calls the `claude` CLI that operators may already have installed.

Current state: greenfield. The project has no existing code.

## Goals / Non-Goals

**Goals:**
- Single hotkey in K9s triggers full context collection + Claude diagnosis
- Left pane renders a human-readable, colored view of YAML/logs/events
- Right pane is an interactive Claude Code session pre-loaded with that context
- Works for Pod, Deployment, Service (the three most common diagnostic targets)
- Zero cluster-side footprint — user-space shell only
- No credential leakage — context is limited to kubectl get/logs/describe output
- Install is idempotent (re-running install does not break existing K9s config)

**Non-Goals:**
- GUI or web UI
- Cluster-wide monitoring or alerting
- Support for Secret resources (explicitly excluded for security)
- Windows or non-tmux terminal multiplexers (initial scope: Linux/macOS + tmux)
- Automatic remediation (Claude suggests; human applies)
- Persistent history of past diagnoses

## Decisions

### D1: Shell scripts over a compiled binary
**Decision**: Implement everything as POSIX-compatible shell scripts.
**Rationale**: Operators can read, audit, and modify shell scripts without a build toolchain. Security-conscious teams are more likely to trust and adopt a tool they can fully inspect. A compiled binary adds supply-chain risk and a build/distribution problem for a v1.
**Alternative considered**: Go CLI — better error handling and testability, but adds compilation, distribution, and a heavier trust requirement.

### D2: tmux as the orchestration layer
**Decision**: Use tmux to manage the split-pane layout.
**Rationale**: tmux is ubiquitous in the target demographic (SREs, platform engineers). It handles pane lifecycle, resizing, and session persistence natively. Using it avoids building a TUI framework from scratch.
**Alternative considered**: A custom TUI (bubbletea/charm) — more polish, but significantly more complexity and a compiled dependency.

### D3: Structured temp file as the data bus
**Decision**: Collector writes to a `mktemp` file with labeled section headers; both the TUI renderer and Claude invoker read from that file independently.
**Rationale**: Decouples collection from rendering and invocation. Each component can be tested or replaced independently. The file persists for the tmux session lifetime, enabling re-rendering or re-invocation without re-collecting.
**Alternative considered**: Passing context as environment variable or pipe — not viable for multi-pane tmux coordination.

### D4: `bat` for YAML highlighting, fallback to plain
**Decision**: Detect `bat` at runtime; use it when available, warn and continue when not.
**Rationale**: Avoids a hard dependency that would block adoption. `bat` is common enough to be the happy path.
**Alternative considered**: Embed ANSI escape sequences manually — fragile and hard to maintain.

### D5: claude CLI invoked with initial prompt, then interactive
**Decision**: Use `claude --print` to inject an initial diagnostic message, then hand off to interactive mode (or use stdin piping depending on claude CLI capabilities at implementation time).
**Rationale**: Gives the user immediate value (a diagnosis appears without them having to type anything) while keeping the session interactive for follow-ups.
**Alternative considered**: `claude-code` MCP integration — more powerful but significantly more complex to wire up from a shell plugin context.

### D6: Secret resources explicitly blocked
**Decision**: If the user triggers the hotkey on a `Secret` resource, refuse and display a warning.
**Rationale**: `kubectl get secret -o yaml` outputs base64-encoded values that are trivially decoded. Even if the user intends to analyze a secret's metadata, the risk of accidentally forwarding credential material to Claude (an external API) is unacceptable. Fail closed.

## Risks / Trade-offs

- **Large log output** → context window overflow in Claude. Mitigation: configurable truncation in claude-invoker (last N lines of logs, last N events). Default thresholds chosen conservatively.
- **kubectl timeout** → slow UX if a node is unresponsive. Mitigation: parallel collection with a per-call timeout flag (`--request-timeout=10s`). User sees partial results rather than a hang.
- **tmux not installed** → integration fails silently from K9s. Mitigation: entry-point script checks for tmux and prints a human-readable error to stderr, which K9s surfaces in its log pane.
- **claude CLI version drift** → invocation flags may change. Mitigation: entry-point validates `claude --version` and warns if below a known-good version. Pinned in README.
- **Parallel kubectl calls increasing API server load** → low risk for 3 calls, but note for large-scale environments. No mitigation planned for v1.
- **Shell injection via resource name** → K9s passes `$NAME` and `$NAMESPACE` as shell variables. Mitigation: entry-point quotes all variable expansions; never evals user-supplied data.

## Migration Plan

1. Run `./install.sh` — appends plugin entries to `~/.config/k9s/plugins.yaml`, copies scripts to `~/.local/bin/`
2. Restart K9s to pick up plugin changes
3. To uninstall: run `./uninstall.sh` — removes corgistration entries from plugins.yaml and scripts from `~/.local/bin/`
4. Rollback: `install.sh` backs up `plugins.yaml` to `plugins.yaml.corgi-bak` before modifying

## Open Questions

- Does the `claude` CLI support a `--system` flag for the system prompt in current release? If not, system prompt must be prepended to the user message.
- Should the tmux session auto-close when the user exits Claude, or persist for re-inspection of the left pane? (Leaning: persist, with a `q` binding to close.)
- Target minimum tmux version? (Tentative: 3.0+ for `tmux display-popup` support if we want a floating window variant later.)

## Why

Kubernetes operators spend significant time context-switching between K9s, terminal windows, and AI tools when diagnosing issues. Corgistration collapses that loop: one hotkey in K9s pulls the relevant resource context and delivers it to Claude Code in a structured tmux layout — no copy-pasting, no window juggling, no lost context.

## What Changes

- New K9s shell plugin config (`~/.config/k9s/plugins.yaml`) registers a hotkey per resource type (Pod, Deployment, Service)
- New context-collector shell script gathers logs, YAML manifest, and events in parallel via `kubectl`
- New tmux orchestrator script arranges a split layout: left pane renders a colored, human-readable TUI view of the collected context; right pane launches Claude Code with that context pre-loaded
- New TUI renderer pipeline syntax-highlights YAML, colorizes log levels (ERROR/WARN/INFO), and surfaces event warnings prominently
- Claude Code is invoked via `claude` CLI with the context piped as stdin or written to a temp file, scoped to diagnosis/fix of the specific resource

## Capabilities

### New Capabilities
- `k9s-plugin`: K9s plugin definition and hotkey bindings that fire the integration per resource type
- `context-collector`: Shell script that runs parallel `kubectl` calls (logs, get -o yaml, describe) and writes structured output to a temp file
- `tmux-orchestrator`: Script that creates or reuses a tmux session, arranges panes, and coordinates data flow between collector and renderers
- `tui-renderer`: Pipeline that formats collected context with syntax highlighting and color-coded severity for human readability in the left pane
- `claude-invoker`: Invocation wrapper that feeds collected context to the `claude` CLI in the right pane with a diagnostic prompt

### Modified Capabilities

(none — greenfield project)

## Impact

- Runtime dependencies: `tmux`, `kubectl`, `claude` CLI, `bat` or `glow` (TUI rendering), `jq`
- K9s configuration: adds entries to `~/.config/k9s/plugins.yaml` (non-destructive append)
- No Kubernetes RBAC changes required beyond what the user's current kubeconfig already permits
- No secrets or credentials stored anywhere; scripts inherit the user's active kubeconfig context
- All scripts are user-space shell — no daemons, no cluster-side components

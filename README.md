# corgistration

K9s + Claude Code + tmux diagnostic integration.

Highlight a Pod, Deployment, or Service in K9s, press **Shift-A**, and get:
- **Left pane**: syntax-highlighted YAML manifest, colorized logs, and events
- **Right pane**: Claude Code pre-loaded with that context, ready to diagnose and suggest fixes

```
┌─────────────────────────────────────┬──────────────────────────────────────┐
│  === YAML MANIFEST ===              │  Diagnosing Pod/api-server...        │
│  apiVersion: v1                     │                                      │
│  kind: Pod                          │  ROOT CAUSE: The container is        │
│  ...                                │  crash-looping because it cannot     │
│  === EVENTS ===                     │  reach the database. The LOGS show   │
│  ! Warning BackOff  kubelet         │  "connection refused" on port 5432.  │
│    Normal  Pulled   kubelet         │                                      │
│  === LOGS ===                       │  FIX:                                │
│  INFO  Starting application         │    kubectl get svc postgres -n default│
│  WARN  Database slow (latency=2.3s) │  Verify the service exists and its   │
│  ERROR Failed to connect: refused   │  ClusterIP is reachable from this    │
│  FATAL Unrecoverable error          │  pod's namespace...                  │
└─────────────────────────────────────┴──────────────────────────────────────┘
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/get.sh | bash
```

> Want to review before running? `curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/get.sh | less`

The installer will:
1. Check all prerequisites and print platform-specific install hints for anything missing
2. Download scripts to `~/.local/bin/`
3. Merge K9s plugin entries into `~/.config/k9s/plugins.yaml` (existing plugins preserved; `.corgi-bak` backup created)

**Restart K9s** after install to pick up the plugin.

### Install from source

```bash
git clone https://github.com/MWest2020/Corgistration.git
cd Corgistration
make install
```

## Prerequisites

| Tool | Minimum version | Install |
|------|-----------------|---------|
| `tmux` | 3.0 | `apt/dnf/brew install tmux` |
| `kubectl` | any | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |
| `claude` CLI | 2.x | `npm install -g @anthropic-ai/claude-code` |
| `yq` | 4.x | [github.com/mikefarah/yq](https://github.com/mikefarah/yq#install) |
| `bat` | any | Optional — enhances YAML highlighting |

## Usage

1. Open K9s and navigate to any Pod, Deployment, or Service
2. Highlight the resource and press **Shift-A**
3. A tmux session named `corgistration` opens with:
   - Left pane: colored context (YAML + events + logs)
   - Right pane: Claude Code with the context pre-loaded
4. Type follow-up questions or ask Claude to generate a fix in the right pane

The tmux session persists. Triggering the hotkey again on a different resource refreshes both panes.

## Customizing the hotkey

Edit `~/.config/k9s/plugins.yaml` and change `shortCut: Shift-A` for any of the three plugin entries (`corgi-pod`, `corgi-deployment`, `corgi-service`).

Valid K9s shortcut format: `Shift-<letter>`, `Ctrl-<letter>`, or a plain letter key.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/uninstall-remote.sh | bash
```

Or if installed from source: `make uninstall`

Removes scripts from `~/.local/bin/` and corgistration entries from `plugins.yaml`.

## Security notes

- **Secret resources are blocked**: triggering the hotkey on a `Secret` prints an error and exits. No credential data is forwarded to Claude.
- **No credential storage**: scripts use your ambient `KUBECONFIG` — nothing is cached or written.
- **Read-only kubectl calls**: only `get`, `describe`, and `logs` are used. No cluster state is modified.
- **Shell injection protection**: all resource names and namespaces are `printf '%q'`-quoted before being passed to tmux/shell.

## Running tests

```bash
make test
```

The smoke test fakes `kubectl` and `claude`, creates a tmux session, and verifies pane layout and rendering.

## Known limitations

- **Linux/macOS + tmux only**: no Windows support in v1
- **Large log volumes**: logs are truncated to the last 100 lines when the context exceeds 500 lines total
- **No persistent history**: each invocation starts a fresh Claude session
- **Deployment/Service logs**: not collected (logs belong to Pods; use K9s to navigate to child Pods)

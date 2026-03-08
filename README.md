```
:::::::::::::::::::::---::::::::-:::::::::::::::-==========:.....::::::::::::::.....::::::::::::::::
:::::::::::::::::::::::::::::::::::::::::::::======++===--==-::.:..:::::::::::::::::..::::::::::::::
:::::::::::::::::::---::::::::::::::::-::-======++==++++=====-::::.:=-..........::::::::::::::::::::
:::::::::::::::::-----::::::::::::-===-====-==++==+*++=======+=::::--==................:::...:.:::::
:::::::::::::::::-----::::::-+*#****++++=--+=====**=--=++*+==*++:.:-+**=:...........................
::::::::::::::::::---::-+*#%%##**#*+*#*+=======+**=*%@@@@%*++**+-...=#%@@=::::::....................
:::::::::::::::::-=*%%%%%%%%%%###**+=+*+=-==+++**+%@@@@@*#%@%%++=:...#@*#*:::::::::.................
:::::::::::::::--%%%%###*######%%%#%*++*++*++**##*+=+*#%%%##%#+++=:...#%@=:-::::::::::::::..........
.::::::::::::::---%%%%%%%%#*+=*%@@%++*+*+#*****##*++####%%%%#*++-:.:::.-*----::::::::::::::::::::...
..:::::::::::::::-:-%%%%#%%#+++++*%****######*+=+*****##%%#**+=::....::...:--::::::::::::::::::::...
::::::::::::::::::::::-%@@%*++++=#**####%**++====+**#***+***+-:.....:..::::.::::::::::::::::::::::::
=======-----------:::::::*##**%#########*+++=+++++---:::::--:::...::::+%%@%*##=:::::::::::::::::::::
++++====================-:-:--=*#*##%%#*++==++++=--:..::--::::::-----%%%@@@@@@@%::::::::::::::::::::
+++++++++++++++++++++++-.-:::::=#####+===+++=+++---::=*----::-----===+%%@@@@@@@#---------:::::::::::
++++++++++++++++++++++-....:::-=*#*+=-==+++++++*---::=@*--------=====+#%@@@@@@#==================+==
+++++++++++++++++****-::..::::--*#+-====+++++++*=====+*##+------=====+#%%%@@%--===++++===++++++++===
+++++++++++++*******-.:::::::---==+=-*++++=+++++===+++++==*#====++++*###%%##==+++++**+++++++++++++++
++++++++++*********-::::::::::::+++=--==++++***=====++++==+++#%%%%###%%@@%#**+*********************+
```

<div align="center">

# corgistration

**Kubernetes diagnostics with AI — K9s + Claude Code + tmux, in your terminal**

`v0.0.1-beta`

</div>

Select a Pod, Deployment, StatefulSet, or Service — get an AI diagnosis in a split terminal with your YAML, Claude, and a live shell side by side.

```
┌──────────────────────┬──────────────────────┐
│  === YAML MANIFEST ===│  (1) Running 2/2     │
│  apiVersion: apps/v1 │                      │
│  kind: Deployment    │  Issue: OOMKilled —  │
│  ...                 │  memory limit too low │
│  === EVENTS ===      │                      │
│  ! Warning OOMKilled │  Run in terminal:    │
│  === LOGS ===        │  kubectl top pod ... │
│  FATAL out of memory ├──────────────────────┤
│                      │  $ kubectl ...       │
└──────────────────────┴──────────────────────┘
```

---

## Install

**Prerequisites — must be set up manually before install:**

| Tool | Notes |
|------|-------|
| `node` + `claude` CLI | Install [Node.js](https://nodejs.org), then `npm install -g @anthropic-ai/claude-code` and `claude login` |
| `kubectl` | [kubernetes.io/docs/tasks/tools](https://kubernetes.io/docs/tasks/tools/) |

**Then install corgistration:**

```bash
# Remote (auto-installs tmux, yq, go, bat if missing)
curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/get.sh | bash -s -- --install-deps

# From source
git clone https://github.com/MWest2020/Corgistration.git
cd Corgistration
make install DEPS=1
```

> Review before running: `curl -fsSL .../get.sh | less`

**Restart K9s** after install to pick up the plugin.

---

## Usage

### Interactive TUI picker (recommended)

```bash
corgi
```

Launches a full-screen picker grouped by resource type:

```
  ── DEPLOYMENTS
► Deployment  api-server    argocd   2/2 ready
  Deployment  redis         default  1/1 ready

  ── STATEFULSETS
  StatefulSet postgres      default  1/1 ready

  ── PODS
  ...
```

`↑/↓` or `j/k` to navigate · `/` to filter · `Enter` to diagnose · `q` to quit

### Direct mode

```bash
corgi Pod      <name> <namespace>
corgi Deployment <name> <namespace>
corgi StatefulSet <name> <namespace>
corgi Service  <name> <namespace>
```

### Via K9s hotkey

Navigate to any resource in K9s and press **Shift-A**.

---

## The diagnostic session

Once a resource is selected, a tmux session named `corgistration` opens with three panes:

| Pane | Content |
|------|---------|
| **Left** | Syntax-highlighted YAML manifest, colorized events and logs |
| **Right top** | Claude — reads context, gives diagnosis, suggests fixes |
| **Right bottom** | Your terminal shell — run the suggested kubectl commands here |

### Navigation

| Key | Action |
|-----|--------|
| `Click` | Focus that pane |
| `Ctrl-b o` | Cycle through panes |
| `Ctrl-b ←/→/↑/↓` | Navigate panes by direction |
| `Ctrl-b [` | Scroll mode (YAML pane) — `q` to exit |
| `Shift+drag` | Copy text (terminal native, bypasses tmux) |
| `Ctrl-b g` | **Return to TUI picker** — select a new resource |
| `Ctrl-b d` | Detach (session keeps running in background) |

Selecting a new resource via `Ctrl-b g` refreshes all panes in place.

---

## Configuration

Config file is created at `~/.config/corgistration/config` on first install.

```bash
# Destructive command policy
#   deny  (default) Claude describes what a destructive action does but never
#                   writes the command — you run it yourself after verifying
#   ask             Claude writes the command but marks it ⚠️ DESTRUCTIVE ACTION
#                   and asks you to confirm first
#   allow           Claude marks it ⚠️ WARNING but proceeds without confirmation
CORGI_DESTRUCTIVE="deny"

# Max context lines sent to Claude before truncation
CORGI_CONTEXT_LINES=500
```

---

## Prerequisites (full list)

| Tool | Min version | Auto-install |
|------|-------------|--------------|
| `tmux` | 3.0 | Yes (`--install-deps`) |
| `kubectl` | any | Yes |
| `node` + `claude` CLI | Node 18+ | **No — manual setup required** |
| `yq` | 4.x | Yes |
| `go` | 1.21+ | Yes |
| `bat` | any | Yes (optional, enhances YAML highlighting) |

---

## Customizing the K9s hotkey

Edit `~/.config/k9s/plugins.yaml` and change `shortCut: Shift-A` for any of the plugin entries (`corgi-pod`, `corgi-deployment`, `corgi-service`, `corgi-statefulset`).

---

## Uninstall

```bash
# Remote
curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/uninstall-remote.sh | bash

# From source
make uninstall
```

---

## Security

- **Secrets blocked**: triggering on a `Secret` resource exits immediately — no credential data is forwarded to Claude
- **Read-only by default**: only `kubectl get`, `describe`, and `logs` are used — no cluster state is modified
- **Destructive commands denied by default**: Claude describes actions but does not write destructive commands (`delete`, `drain`, `scale to 0`, etc.)
- **No credential storage**: uses your ambient `KUBECONFIG` — nothing is cached or persisted
- **Shell injection protection**: all resource names and namespaces are `printf '%q'`-quoted before passing to tmux/shell

---

## Docs

- [Use cases](docs/use-cases.md) — real-world diagnostic scenarios
- [Configuration reference](docs/configuration.md) — all config options
- [Keybindings](docs/keybindings.md) — full tmux key reference

---

## Known limitations

- Linux/macOS + tmux only (no Windows)
- Logs truncated to last 100 lines when context exceeds `CORGI_CONTEXT_LINES`
- Each session starts a fresh Claude conversation (no persistent history)
- Deployment/Service logs not collected — navigate to child Pods in K9s or picker

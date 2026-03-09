# kubectl colorizer

Syntax-highlights `kubectl` commands in Claude's output — read-only verbs in yellow/green, mutating in orange, destructive in red — without breaking Claude's interactive TUI.

## How it works

Claude runs inside a PTY (pseudo-terminal), so it behaves as if writing to a real terminal. The colorizer intercepts each output line and applies ANSI colors to any `kubectl` command it finds, then passes everything else through unchanged.

```
your terminal
     │
     └─► kubectl-colorize (PTY wrapper)
              │
              └─► claude (thinks it has a real terminal)
```

## Color map

| Token | Color | Examples |
|-------|-------|---------|
| `kubectl` / `k` | white | |
| Read verbs | yellow | `get`, `describe`, `explain` |
| Streaming verbs | green | `logs`, `exec`, `top`, `port-forward` |
| Mutating verbs | orange | `apply`, `create`, `patch`, `scale`, `rollout` |
| Destructive verbs | **red** | `delete`, `drain` |
| Sub-commands | light orange | `restart`, `status`, `history`, `undo` |
| Info verbs | purple | `config`, `auth`, `version` |
| Resource types | cyan | `pod`, `deploy`, `svc`, `cm`, `secret`... |
| Flags | gray | `--output`, `-l`, `--field-selector` |
| `-n` / `--namespace` | blue | |
| Namespace value | **light blue bold** | `production`, `kube-system` |

## Install

```bash
# From corgistration root:
bash scripts/setup_colorize.sh
source ~/.bashrc

# Test filter mode:
echo "kubectl delete pod my-pod -n production" | kubectl-colorize

# Test PTY wrapper:
kubectl-colorize -- claude --version
```

The setup script:
1. Copies `kubectl-colorize` to `~/.local/bin/`
2. Adds a `claude()` shell function to `~/.bashrc` that wraps the real `claude` CLI in the PTY colorizer

## Usage

After `source ~/.bashrc`, just use `claude` normally — colorization is automatic:

```bash
claude "why is my pod crashlooping?"
# Claude's response: kubectl describe pod ... — highlighted in real time
```

### Disable colorization

```bash
# Per-invocation:
NO_COLOR=1 claude "..."

# Permanent (add to ~/.bashrc):
export NO_COLOR=1
```

### Filter mode (pipe)

```bash
# Colorize any text on stdin:
cat some-runbook.txt | kubectl-colorize

# Works with less -R for scrolling:
kubectl-colorize < runbook.txt | less -R
```

## Uninstall

```bash
rm ~/.local/bin/kubectl-colorize
# Remove the 'corgistration: kubectl colorizer' block from ~/.bashrc
```

## Known limitations

- Colorizes lines that *contain* kubectl commands — surrounding prose passes through unchanged
- Backtick inline code (`` `kubectl get pods` ``) is detected and colorized in place
- Multi-line kubectl commands (backslash continuation) are not joined — each line colorized independently
- PTY mode is Linux/macOS only (requires Python `pty` module)

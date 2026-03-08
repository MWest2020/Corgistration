# Configuration Reference

Config file location: `~/.config/corgistration/config`

Created automatically on first install with safe defaults. Never overwritten on upgrade — edit it freely.

---

## CORGI_DESTRUCTIVE

Controls how Claude handles destructive Kubernetes commands (`delete`, `scale to 0`, `drain`, `cordon`, `force-kill`, `patch --force`).

| Value | Behaviour |
|-------|-----------|
| `deny` | **(default)** Claude describes what the action does and its blast radius, but does not write the command. You run it yourself in the terminal pane after verifying. |
| `ask` | Claude writes the command, prefixes it with `⚠️ DESTRUCTIVE ACTION — verify before running`, explains the blast radius, and asks you to confirm. |
| `allow` | Claude writes the command with a `⚠️ WARNING` prefix but does not ask for confirmation. |

**Read-only commands** (`get`, `describe`, `logs`, `top`) are always shown freely regardless of this setting.

```bash
CORGI_DESTRUCTIVE="deny"
```

---

## CORGI_CONTEXT_LINES

Maximum number of lines of context (YAML + events + logs) sent to Claude before truncation kicks in.

When the context exceeds this limit:
- Events are truncated to the last 20 entries
- Logs are truncated to the last 100 lines
- YAML manifest is always sent in full

Lower this if Claude responses feel slow or you hit token limits. Raise it if you need more log history.

```bash
CORGI_CONTEXT_LINES=500
```

---

## Example: minimal secure config

```bash
# ~/.config/corgistration/config

# Never write destructive commands — describe only
CORGI_DESTRUCTIVE="deny"

# Tighter context window for faster responses
CORGI_CONTEXT_LINES=300
```

## Example: power user config

```bash
# ~/.config/corgistration/config

# Warn and ask — I want to see the commands but with guardrails
CORGI_DESTRUCTIVE="ask"

# More log history
CORGI_CONTEXT_LINES=800
```

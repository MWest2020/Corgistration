# Keybindings

All keybindings active inside the `corgistration` tmux session.

The status bar at the bottom of the session shows the most common ones at all times.

---

## Pane navigation

| Key | Action |
|-----|--------|
| `Click` | Focus that pane (mouse mode is on) |
| `Ctrl-b o` | Cycle to next pane |
| `Ctrl-b ←` | Move focus left |
| `Ctrl-b →` | Move focus right |
| `Ctrl-b ↑` | Move focus up |
| `Ctrl-b ↓` | Move focus down |

---

## Workflow

| Key | Action |
|-----|--------|
| `Ctrl-b g` | Open TUI picker — select a new resource to diagnose. All panes refresh on selection. |
| `Ctrl-b d` | Detach from session. Session keeps running in the background. Re-attach with `tmux attach -t corgistration`. |

---

## Copying text

| Method | How |
|--------|-----|
| **Shift+drag** | Hold Shift, click and drag — uses your terminal's native selection, bypasses tmux. Works in any pane. Best for copying Claude output. |
| **tmux copy mode** | `Ctrl-b [` to enter, arrow keys or `j/k` to navigate, `Space` to start selection, `Enter` to copy to tmux clipboard, `Ctrl-b ]` to paste. `q` to exit. |

---

## Scrolling the YAML pane

The left pane renders and stays frozen (no shell prompt). To scroll:

1. Click the left pane to focus it
2. `Ctrl-b [` to enter scroll mode
3. Arrow keys / `PgUp` / `PgDn` to scroll
4. `q` to exit scroll mode

---

## Exiting Claude

Type `exit` or press `Ctrl-d` in the Claude pane to end the session.
The pane closes. Use `Ctrl-b g` to start a new diagnostic session.

---

## tmux prefix

The default tmux prefix is `Ctrl-b`. If you have a custom prefix set in `~/.tmux.conf`, substitute that instead.

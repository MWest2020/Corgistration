#!/usr/bin/env bash
# orchestrate.sh — manage tmux session layout for corgistration
# Usage: orchestrate.sh <context-file> <kind> <name> <namespace>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CONTEXT_FILE="${1:-}"
KIND="${2:-}"
NAME="${3:-}"
NAMESPACE="${4:-}"

if [[ -z "$CONTEXT_FILE" || -z "$KIND" || -z "$NAME" || -z "$NAMESPACE" ]]; then
  corgi_log ERROR "Usage: orchestrate.sh <context-file> <kind> <name> <namespace>"
  exit 1
fi

SESSION="corgistration"
WIN_CONTEXT="${SESSION}:0"   # window 0 — YAML / events / logs viewer
WIN_CLAUDE="${SESSION}:1"    # window 1 — Claude interactive (full width, copyable)

# Shell-quote all user-derived values to prevent injection via resource name/namespace
Q_SCRIPT_DIR="$(printf '%q' "${SCRIPT_DIR}")"
Q_CONTEXT="$(printf '%q' "${CONTEXT_FILE}")"
Q_KIND="$(printf '%q' "${KIND}")"
Q_NAME="$(printf '%q' "${NAME}")"
Q_NS="$(printf '%q' "${NAMESPACE}")"

RENDER_CMD="${Q_SCRIPT_DIR}/render.sh ${Q_CONTEXT}"
INVOKE_CMD="${Q_SCRIPT_DIR}/claude-invoke.sh ${Q_CONTEXT} ${Q_KIND} ${Q_NAME} ${Q_NS}"

# ── Session management ────────────────────────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
  corgi_log INFO "Reusing existing tmux session: $SESSION"
  tmux send-keys -t "${WIN_CONTEXT}" "clear && ${RENDER_CMD}" Enter
  tmux send-keys -t "${WIN_CLAUDE}"  "clear && ${INVOKE_CMD}" Enter
else
  corgi_log INFO "Creating new tmux session: $SESSION"

  # Window 0 — context viewer
  tmux new-session -d -s "$SESSION" -n "context" -x 220 -y 50
  tmux set-option -t "${WIN_CONTEXT}" remain-on-exit on
  tmux send-keys -t "${WIN_CONTEXT}" "${RENDER_CMD}" Enter

  # Window 1 — Claude (full width so copy mode works cleanly)
  tmux new-window -t "$SESSION" -n "claude"
  tmux send-keys -t "${WIN_CLAUDE}" "source ${Q_SCRIPT_DIR}/lib.sh && corgi_banner ${Q_KIND} ${Q_NAME} ${Q_NS} && ${INVOKE_CMD}" Enter
fi

# ── Attach to window 1 (Claude) so user lands in the interactive pane ─────────
if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "${WIN_CLAUDE}"
else
  tmux attach-session -t "${WIN_CLAUDE}"
fi

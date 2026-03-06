#!/usr/bin/env bash
# corgistration.sh — entry point invoked by the K9s plugin
# Usage: corgistration.sh <kind> <name> <namespace>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# ── Argument validation ──────────────────────────────────────────────────────
KIND="${1:-}"
NAME="${2:-}"
NAMESPACE="${3:-}"

if [[ -z "$KIND" || -z "$NAME" || -z "$NAMESPACE" ]]; then
  corgi_log ERROR "Usage: corgistration.sh <kind> <name> <namespace>"
  exit 1
fi

# ── Prerequisite checks ──────────────────────────────────────────────────────
require_cmd tmux    "https://github.com/tmux/tmux — install via your OS package manager" || exit 1
require_cmd kubectl "https://kubernetes.io/docs/tasks/tools/" || exit 1
require_cmd claude  "https://claude.ai/claude-code — install via: npm install -g @anthropic-ai/claude-code" || exit 1

# ── Collect context ──────────────────────────────────────────────────────────
CONTEXT_FILE="$("${SCRIPT_DIR}/collect.sh" "$KIND" "$NAME" "$NAMESPACE")"
if [[ -z "$CONTEXT_FILE" || ! -f "$CONTEXT_FILE" ]]; then
  corgi_log ERROR "Context collection failed for $KIND/$NAME in $NAMESPACE"
  exit 1
fi

# ── Launch tmux layout ───────────────────────────────────────────────────────
exec "${SCRIPT_DIR}/orchestrate.sh" "$CONTEXT_FILE" "$KIND" "$NAME" "$NAMESPACE"

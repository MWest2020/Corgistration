#!/usr/bin/env bash
# claude-invoke.sh — feed collected K8s context to Claude Code for diagnosis
# Usage: claude-invoke.sh <context-file> <kind> <name> <namespace>
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

CONTEXT_FILE="${1:-}"
KIND="${2:-}"
NAME="${3:-}"
NAMESPACE="${4:-}"

if [[ -z "$CONTEXT_FILE" || -z "$KIND" || -z "$NAME" || -z "$NAMESPACE" ]]; then
  corgi_log ERROR "Usage: claude-invoke.sh <context-file> <kind> <name> <namespace>"
  exit 1
fi

# ── Minimum claude CLI version ────────────────────────────────────────────────
REQUIRED_CLAUDE_MAJOR=2
CLAUDE_VERSION="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo '0.0.0')"
CLAUDE_MAJOR="$(printf '%s' "$CLAUDE_VERSION" | cut -d. -f1)"
if (( CLAUDE_MAJOR < REQUIRED_CLAUDE_MAJOR )); then
  corgi_log WARN "claude CLI version ${CLAUDE_VERSION} may be unsupported (minimum: ${REQUIRED_CLAUDE_MAJOR}.x). See README for upgrade instructions."
fi

# ── Truncation ────────────────────────────────────────────────────────────────
CONTEXT_LINES="$(wc -l < "$CONTEXT_FILE")"
MAX_LINES=500
TRUNCATION_NOTICE=""

if (( CONTEXT_LINES > MAX_LINES )); then
  CONTEXT_LINES_TRUNC="$(mktemp)"
  trap 'rm -f "$CONTEXT_LINES_TRUNC"' EXIT

  # Extract sections and truncate logs + events
  awk '
    /^=== YAML MANIFEST ===$/ { section="yaml" }
    /^=== EVENTS ===$/ { section="events"; events_lines=0 }
    /^=== LOGS ===$/ { section="logs"; logs_lines=0 }
    section=="yaml" { print; next }
    section=="events" && events_lines < 20 { print; events_lines++; next }
    section=="logs" { logs_buf[logs_lines++] = $0 }
    END {
      # Print last 100 log lines
      start = (logs_lines > 100) ? logs_lines - 100 : 0
      for (i = start; i < logs_lines; i++) print logs_buf[i]
    }
  ' "$CONTEXT_FILE" > "$CONTEXT_LINES_TRUNC"

  CONTEXT_FILE="$CONTEXT_LINES_TRUNC"
  TRUNCATION_NOTICE="[NOTE: Context was truncated to fit context window. Logs limited to last 100 lines; events to last 20 entries.]"
fi

# ── System prompt ─────────────────────────────────────────────────────────────
SYSTEM_PROMPT="You are an expert Kubernetes platform engineer and SRE.
The user is investigating a Kubernetes resource. Context (YAML, events, logs) is available.
Be concise. Lead with the most likely problem and a single actionable fix.
Do not repeat the manifest back. Ask clarifying questions if needed."

# ── Initial user message ──────────────────────────────────────────────────────
CONTEXT_CONTENT="$(cat "$CONTEXT_FILE")"
INITIAL_PROMPT="Diagnose: ${KIND}/${NAME} in namespace ${NAMESPACE}
${TRUNCATION_NOTICE}

${CONTEXT_CONTENT}

Respond with: (1) status summary in one line, (2) most likely issue, (3) recommended fix or next step."

# ── Launch Claude in interactive mode ────────────────────────────────────────
exec claude \
  --system-prompt "${SYSTEM_PROMPT}" \
  "${INITIAL_PROMPT}"

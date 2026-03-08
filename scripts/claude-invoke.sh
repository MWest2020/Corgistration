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

# ── Load user config ──────────────────────────────────────────────────────────
CONFIG_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/corgistration/config"
# Defaults
CORGI_DESTRUCTIVE="ask"   # ask | allow | deny
CORGI_CONTEXT_LINES=500
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# ── Minimum claude CLI version ────────────────────────────────────────────────
REQUIRED_CLAUDE_MAJOR=2
CLAUDE_VERSION="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo '0.0.0')"
CLAUDE_MAJOR="$(printf '%s' "$CLAUDE_VERSION" | cut -d. -f1)"
if (( CLAUDE_MAJOR < REQUIRED_CLAUDE_MAJOR )); then
  corgi_log WARN "claude CLI version ${CLAUDE_VERSION} may be unsupported (minimum: ${REQUIRED_CLAUDE_MAJOR}.x)."
fi

# ── Truncation ────────────────────────────────────────────────────────────────
CONTEXT_LINES_COUNT="$(wc -l < "$CONTEXT_FILE")"
TRUNCATION_NOTICE=""

if (( CONTEXT_LINES_COUNT > CORGI_CONTEXT_LINES )); then
  CONTEXT_FILE_TRUNC="$(mktemp)"
  trap 'rm -f "$CONTEXT_FILE_TRUNC"' EXIT

  awk '
    /^=== YAML MANIFEST ===$/ { section="yaml" }
    /^=== EVENTS ===$/ { section="events"; events_lines=0 }
    /^=== LOGS ===$/ { section="logs"; logs_lines=0 }
    section=="yaml" { print; next }
    section=="events" && events_lines < 20 { print; events_lines++; next }
    section=="logs" { logs_buf[logs_lines++] = $0 }
    END {
      start = (logs_lines > 100) ? logs_lines - 100 : 0
      for (i = start; i < logs_lines; i++) print logs_buf[i]
    }
  ' "$CONTEXT_FILE" > "$CONTEXT_FILE_TRUNC"

  CONTEXT_FILE="$CONTEXT_FILE_TRUNC"
  TRUNCATION_NOTICE="[NOTE: Context truncated — logs limited to last 100 lines, events to last 20.]"
fi

# ── Destructive command policy ────────────────────────────────────────────────
case "$CORGI_DESTRUCTIVE" in
  allow)
    DESTRUCTIVE_INSTRUCTION="When suggesting destructive commands (delete, scale to 0, drain, cordon, force-kill, patch --force), always prefix the code block with a bold warning line:
⚠️  DESTRUCTIVE ACTION — double-check before running"
    ;;
  deny)
    DESTRUCTIVE_INSTRUCTION="Do NOT write destructive commands (delete, scale to 0, drain, cordon, force-kill, patch --force) in your responses.
If a destructive action is the correct fix: describe exactly what it does and why, then tell the user to run it themselves in the terminal after verifying.
You may show read-only commands (get, describe, logs, top) freely."
    ;;
  ask|*)
    DESTRUCTIVE_INSTRUCTION="When a destructive command (delete, scale to 0, drain, cordon, force-kill, patch --force) is the right fix:
1. Prefix the code block with:
⚠️  DESTRUCTIVE ACTION — verify before running
2. On the next line explain the blast radius in one sentence.
3. Ask the user to confirm before proceeding."
    ;;
esac

# ── System prompt ─────────────────────────────────────────────────────────────
SYSTEM_PROMPT="You are an expert Kubernetes platform engineer and SRE.
The user is investigating a Kubernetes resource. Context (YAML, events, logs) is available.
Be concise. Lead with the most likely problem and a single actionable fix.
Do not repeat the manifest back. Ask clarifying questions if needed.

${DESTRUCTIVE_INSTRUCTION}"

# ── Initial user message — reference file, not content ───────────────────────
# Passing large context as a shell argument hits OS ARG_MAX limits.
# Claude Code has native file-reading capability; pass the path instead.
INITIAL_PROMPT="Diagnose: ${KIND}/${NAME} in namespace ${NAMESPACE}
${TRUNCATION_NOTICE}

Context file (YAML manifest, events, logs): ${CONTEXT_FILE}

Please read that file, then respond with:
(1) status summary in one line
(2) most likely issue
(3) recommended fix or next step — read-only kubectl commands only"

# ── Launch Claude in interactive mode ─────────────────────────────────────────
exec claude \
  --system-prompt "${SYSTEM_PROMPT}" \
  "${INITIAL_PROMPT}"

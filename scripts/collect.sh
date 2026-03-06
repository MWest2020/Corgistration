#!/usr/bin/env bash
# collect.sh — gather K8s resource context in parallel
# Usage: collect.sh <kind> <name> <namespace>
# Prints the path to the temp file containing structured output.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

KIND="${1:-}"
NAME="${2:-}"
NAMESPACE="${3:-}"

if [[ -z "$KIND" || -z "$NAME" || -z "$NAMESPACE" ]]; then
  corgi_log ERROR "Usage: collect.sh <kind> <name> <namespace>"
  exit 1
fi

# ── Security: block Secret resources ────────────────────────────────────────
if [[ "${KIND,,}" == "secret" ]]; then
  corgi_log ERROR "Secret resources are excluded to prevent credential exposure."
  exit 2
fi

# ── Temp file ────────────────────────────────────────────────────────────────
TMPFILE="$(mktemp /tmp/corgistration-XXXXXX.txt)"
trap 'rm -f "$TMPFILE"' INT TERM  # remove on signal; caller owns the file on success

# ── Parallel collection ───────────────────────────────────────────────────────
YAML_TMP="$(mktemp)"
EVENTS_TMP="$(mktemp)"
LOGS_TMP="$(mktemp)"

collect_yaml() {
  kubectl get "${KIND,,}" "${NAME}" \
    --namespace="${NAMESPACE}" \
    --output=yaml \
    --request-timeout=10s \
    2>&1 > "$YAML_TMP" || true
}

collect_events() {
  kubectl describe "${KIND,,}" "${NAME}" \
    --namespace="${NAMESPACE}" \
    --request-timeout=10s \
    2>&1 > "$EVENTS_TMP" || true
}

collect_logs() {
  if [[ "${KIND,,}" == "pod" ]]; then
    kubectl logs "${NAME}" \
      --namespace="${NAMESPACE}" \
      --tail=200 \
      --timestamps=true \
      --request-timeout=10s \
      2>&1 > "$LOGS_TMP" || true
  else
    printf "(log collection not applicable for %s resources)\n" "$KIND" > "$LOGS_TMP"
  fi
}

# Launch all three in parallel
collect_yaml   &
collect_events &
collect_logs   &
wait

# ── Assemble structured output ────────────────────────────────────────────────
{
  printf '=== YAML MANIFEST ===\n'
  cat "$YAML_TMP"
  printf '\n=== EVENTS ===\n'
  cat "$EVENTS_TMP"
  printf '\n=== LOGS ===\n'
  cat "$LOGS_TMP"
} > "$TMPFILE"

rm -f "$YAML_TMP" "$EVENTS_TMP" "$LOGS_TMP"

# ── Emit path for caller ──────────────────────────────────────────────────────
printf '%s\n' "$TMPFILE"

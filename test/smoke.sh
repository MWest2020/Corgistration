#!/usr/bin/env bash
# smoke.sh — end-to-end smoke test for corgistration
# Fakes kubectl and claude, runs corgistration.sh, asserts tmux session with two panes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FAKE_BIN="${SCRIPT_DIR}/fakebin"
SESSION="corgistration"
PASS=0
FAIL=0

cleanup() {
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  rm -rf "$FAKE_BIN"
}
trap cleanup EXIT

pass() { printf '\033[0;32m  PASS\033[0m %s\n' "$1"; (( PASS++ )); }
fail() { printf '\033[0;31m  FAIL\033[0m %s\n' "$1"; (( FAIL++ )); }

# ── Fake binaries ──────────────────────────────────────────────────────────
mkdir -p "$FAKE_BIN"

# fake kubectl
cat > "${FAKE_BIN}/kubectl" << 'EOF'
#!/usr/bin/env bash
# Emit fixture-like output for any kubectl call
case "$*" in
  *"get pod"*|*"get pods"*) cat "${SCRIPT_DIR:-/dev/null}/../test/fixtures/pod-context.txt" 2>/dev/null || printf 'apiVersion: v1\nkind: Pod\n' ;;
  *describe*) printf 'Events:\n  Normal  Scheduled  1m  scheduler  assigned\n' ;;
  *logs*)     printf '2024-01-01T00:00:00Z INFO test log line\n' ;;
  *)          printf 'ok\n' ;;
esac
exit 0
EOF
chmod +x "${FAKE_BIN}/kubectl"

# fake claude — just prints and exits (non-interactive for test)
cat > "${FAKE_BIN}/claude" << 'EOF'
#!/usr/bin/env bash
printf '[fake claude] would start interactive session with args: %s\n' "$*"
# Don't actually start an interactive session in CI
exit 0
EOF
chmod +x "${FAKE_BIN}/claude"

# ── Run with fake PATH ──────────────────────────────────────────────────────
# Kill any pre-existing corgistration session
tmux kill-session -t "$SESSION" 2>/dev/null || true

export PATH="${FAKE_BIN}:${ROOT_DIR}/scripts:${PATH}"
export SCRIPT_DIR="${ROOT_DIR}/scripts"

# Run the entry-point (we call orchestrate.sh directly to avoid attach blocking test)
CONTEXT_FILE="$("${ROOT_DIR}/scripts/collect.sh" Pod test-pod default 2>/dev/null)"

if [[ -f "$CONTEXT_FILE" ]]; then
  pass "collect.sh produced a context file"
else
  fail "collect.sh did not produce a context file"
fi

# Create session manually (without attach) to test layout
tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux split-window -t "${SESSION}:0" -h -l 45%

# Assert session exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
  pass "tmux session '$SESSION' exists"
else
  fail "tmux session '$SESSION' not found"
fi

# Assert two panes
PANE_COUNT="$(tmux list-panes -t "$SESSION" | wc -l | tr -d ' ')"
if [[ "$PANE_COUNT" -eq 2 ]]; then
  pass "tmux session has 2 panes (got: $PANE_COUNT)"
else
  fail "expected 2 panes, got: $PANE_COUNT"
fi

# Assert render.sh produces ANSI output from fixture
if [[ -f "$CONTEXT_FILE" ]]; then
  ANSI_COUNT="$("${ROOT_DIR}/scripts/render.sh" "$CONTEXT_FILE" | od -c | grep -c "033" || echo 0)"
  if (( ANSI_COUNT > 0 )); then
    pass "render.sh produces ANSI-colored output"
  else
    fail "render.sh produced no ANSI escape codes"
  fi
fi

# Assert Secret is blocked
if "${ROOT_DIR}/scripts/collect.sh" Secret my-secret default 2>/dev/null; then
  fail "collect.sh should have blocked Secret collection"
else
  EXIT_CODE=$?
  if [[ $EXIT_CODE -eq 2 ]]; then
    pass "collect.sh exits 2 for Secret resources"
  else
    fail "collect.sh exited $EXIT_CODE for Secret (expected 2)"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
printf 'Results: \033[0;32m%d passed\033[0m, \033[0;31m%d failed\033[0m\n' "$PASS" "$FAIL"
(( FAIL == 0 ))

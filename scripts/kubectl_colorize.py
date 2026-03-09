#!/usr/bin/env python3
"""
kubectl_colorize.py — ANSI syntax highlighter for kubectl commands in streaming text.

Two modes:
  Filter mode  — reads stdin, colorizes kubectl lines, writes to stdout
                 echo "kubectl get pods -n default" | kubectl-colorize

  PTY wrapper  — runs a command in a pseudo-terminal so it behaves as if
                 writing to a real terminal, while we colorize the output
                 kubectl-colorize -- claude --system-prompt "..." "prompt"

Usage:
  kubectl-colorize [--no-color] [-- <command> [args...]]
"""

import sys
import re
import os

# ── ANSI codes ────────────────────────────────────────────────────────────────

RESET = '\033[0m'
C = {
    'white':        '\033[97m',
    'yellow':       '\033[33m',
    'green':        '\033[32m',
    'orange':       '\033[38;5;214m',
    'red':          '\033[31m',
    'light_orange': '\033[38;5;215m',
    'blue':         '\033[34m',
    'light_blue':   '\033[94m',
    'light_blue_bold': '\033[94m\033[1m',
    'cyan':         '\033[36m',
    'gray':         '\033[90m',
    'purple':       '\033[35m',
}

def col(name, text):
    code = C.get(name, '')
    return f"{code}{text}{RESET}" if code else text

# ── Token tables ──────────────────────────────────────────────────────────────

VERBS = {
    # read-only
    'get': 'yellow', 'describe': 'yellow', 'explain': 'yellow',
    # streaming / exec
    'logs': 'green', 'exec': 'green', 'top': 'green', 'port-forward': 'green', 'attach': 'green',
    # mutating
    'apply': 'orange', 'rollout': 'orange', 'scale': 'orange',
    'create': 'orange', 'patch': 'orange', 'edit': 'orange', 'label': 'orange',
    'annotate': 'orange', 'cordon': 'orange', 'uncordon': 'orange', 'taint': 'orange',
    # destructive
    'delete': 'red', 'drain': 'red',
    # rollout sub-commands
    'restart': 'light_orange', 'status': 'light_orange',
    'history': 'light_orange', 'undo': 'light_orange', 'pause': 'light_orange', 'resume': 'light_orange',
    # info
    'config': 'purple', 'auth': 'purple', 'version': 'purple', 'api-resources': 'purple',
    'api-versions': 'purple', 'cluster-info': 'purple',
}

RESOURCES = {
    'pod', 'pods', 'po',
    'deployment', 'deployments', 'deploy',
    'service', 'services', 'svc',
    'configmap', 'configmaps', 'cm',
    'secret', 'secrets',
    'namespace', 'namespaces', 'ns',
    'node', 'nodes', 'no',
    'ingress', 'ingresses', 'ing',
    'statefulset', 'statefulsets', 'sts',
    'daemonset', 'daemonsets', 'ds',
    'replicaset', 'replicasets', 'rs',
    'job', 'jobs',
    'cronjob', 'cronjobs', 'cj',
    'persistentvolume', 'persistentvolumes', 'pv',
    'persistentvolumeclaim', 'persistentvolumeclaims', 'pvc',
    'serviceaccount', 'serviceaccounts', 'sa',
    'role', 'roles',
    'rolebinding', 'rolebindings',
    'clusterrole', 'clusterroles',
    'clusterrolebinding', 'clusterrolebindings',
    'event', 'events', 'ev',
    'endpoint', 'endpoints', 'ep',
    'horizontalpodautoscaler', 'horizontalpodautoscalers', 'hpa',
    'networkpolicy', 'networkpolicies', 'netpol',
    'poddisruptionbudget', 'poddisruptionbudgets', 'pdb',
    'storageclass', 'storageclasses', 'sc',
    'limitrange', 'limitranges',
    'resourcequota', 'resourcequotas',
    'all',
}

NS_FLAGS = {'-n', '--namespace'}
ALL_NS_FLAGS = {'--all-namespaces', '-A'}

# Strip existing ANSI for analysis only
ANSI_RE = re.compile(r'\033\[[0-9;]*[a-zA-Z]')

# Detect kubectl/k presence in a line
KUBECTL_RE = re.compile(
    r'\bkubectl\b'
    r'|\bk\s+(?:' + '|'.join(VERBS.keys()) + r')\b'
    r'|\`kubectl\b'
    r'|\`k\s+(?:' + '|'.join(VERBS.keys()) + r')\b'
)

# ── Colorizer ─────────────────────────────────────────────────────────────────

def colorize_token(token, role):
    """Apply color to a single token string."""
    if role == 'namespace_value':
        return f"{C['light_blue']}\033[1m{token}{RESET}"
    return col(role, token)

def colorize_kubectl_segment(segment):
    """
    Colorize a segment of text that starts with 'kubectl' or 'k'.
    segment is a clean (no ANSI) string starting with the kubectl token.
    Returns colorized string.
    """
    # Split into (token, trailing_whitespace) pairs
    token_re = re.compile(r'(\S+)(\s*)')
    matches = list(token_re.finditer(segment))

    result = []
    verb_seen = False
    next_is_ns = False

    for i, m in enumerate(matches):
        token = m.group(1)
        space = m.group(2)
        lower = token.lower()

        # kubectl / k keyword
        if i == 0 and lower in ('kubectl', 'k'):
            result.append(col('white', token) + space)
            continue

        # Next token is namespace value
        if next_is_ns:
            result.append(colorize_token(token, 'namespace_value') + space)
            next_is_ns = False
            continue

        # --flag=value
        if token.startswith('-') and '=' in token:
            flag, val = token.split('=', 1)
            if flag in NS_FLAGS:
                result.append(col('blue', flag) + '=' + colorize_token(val, 'namespace_value') + space)
            else:
                result.append(col('gray', flag) + '=' + val + space)
            continue

        # Flags
        if token.startswith('-'):
            if token in NS_FLAGS:
                result.append(col('blue', token) + space)
                next_is_ns = True
            elif token in ALL_NS_FLAGS:
                result.append(col('blue', token) + space)
            else:
                result.append(col('gray', token) + space)
            continue

        # Verb (first non-flag token after kubectl)
        if not verb_seen:
            verb_seen = True
            color = VERBS.get(lower)
            if color:
                result.append(col(color, token) + space)
            else:
                result.append(token + space)
            continue

        # resource/name  e.g. deploy/my-app
        if '/' in token:
            left, right = token.split('/', 1)
            if left.lower() in RESOURCES:
                result.append(col('cyan', left) + '/' + right + space)
                continue

        # Resource type
        if lower in RESOURCES:
            result.append(col('cyan', token) + space)
            continue

        # Rollout sub-commands etc.
        color = VERBS.get(lower)
        if color:
            result.append(col(color, token) + space)
            continue

        result.append(token + space)

    return ''.join(result)


def colorize_line(line):
    """
    Colorize a single line. Handles:
    - Plain kubectl commands
    - Backtick-wrapped inline code: `kubectl ...`
    - Passes non-kubectl lines through unchanged
    """
    stripped = ANSI_RE.sub('', line)

    if not KUBECTL_RE.search(stripped):
        return line

    # Process backtick-wrapped segments separately
    # Pattern: `kubectl...` or `k get...`
    backtick_re = re.compile(r'`(kubectl\b[^`]*|k\s+(?:' + '|'.join(VERBS.keys()) + r')[^`]*)`')

    def colorize_backtick(m):
        inner = m.group(1)
        colored = colorize_kubectl_segment(inner)
        return '`' + colored + '`'

    # First handle backtick segments
    result = backtick_re.sub(colorize_backtick, stripped)

    # Then handle bare kubectl lines
    # Find kubectl/k at start of token (possibly after leading whitespace/prompt chars)
    bare_re = re.compile(r'(?<![`\w])(kubectl\b|k\s+(?=' + '|'.join(VERBS.keys()) + r'\b))(.*?)(?=\s*$|\s*[|&;])', re.DOTALL)

    def colorize_bare(m):
        return colorize_kubectl_segment(m.group(0))

    result = bare_re.sub(colorize_bare, result)
    return result


def process_line(line, no_color=False):
    if no_color:
        return line
    return colorize_line(line)

# ── Filter mode ───────────────────────────────────────────────────────────────

def run_filter(no_color=False):
    """Stdin → stdout filter."""
    try:
        for raw_line in sys.stdin:
            sys.stdout.write(process_line(raw_line, no_color))
            sys.stdout.flush()
    except KeyboardInterrupt:
        pass
    except BrokenPipeError:
        pass

# ── PTY wrapper mode ──────────────────────────────────────────────────────────

def run_pty(cmd, no_color=False):
    """
    Run cmd in a PTY so it behaves as if writing to a real terminal.
    Intercept output and colorize kubectl lines transparently.
    Propagates the child's exit code.
    """
    import pty
    import tty
    import termios
    import select
    import signal

    buf = b''

    def master_read(fd):
        nonlocal buf
        try:
            data = os.read(fd, 4096)
        except OSError:
            return b''

        if no_color:
            return data

        buf += data
        output = b''

        # Process complete lines
        while b'\n' in buf:
            line_bytes, buf = buf.split(b'\n', 1)
            line = line_bytes.decode('utf-8', errors='replace') + '\n'
            colorized = process_line(line, no_color)
            output += colorized.encode('utf-8', errors='replace')

        # Flush incomplete buffer immediately (prompts, partial output)
        if buf:
            output += buf
            buf = b''

        return output

    try:
        status = pty.spawn(cmd, master_read)
        # Propagate child exit code
        if os.WIFEXITED(status):
            sys.exit(os.WEXITSTATUS(status))
        elif os.WIFSIGNALED(status):
            sys.exit(128 + os.WTERMSIG(status))
        else:
            sys.exit(0)
    except FileNotFoundError:
        print(f"kubectl-colorize: command not found: {cmd[0]}", file=sys.stderr)
        sys.exit(127)
    except Exception as e:
        print(f"kubectl-colorize: {e}", file=sys.stderr)
        # Fallback: just exec the command directly without colorization
        os.execvp(cmd[0], cmd)

# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    args = sys.argv[1:]
    no_color = False

    # Check for --no-color
    if '--no-color' in args:
        args.remove('--no-color')
        no_color = True

    # Respect NO_COLOR env var (https://no-color.org)
    if os.environ.get('NO_COLOR'):
        no_color = True

    # Check if terminal supports color
    if not no_color and not sys.stdout.isatty() and '--' not in args:
        # Filter mode to a non-TTY: still colorize (user may redirect to less -R etc.)
        pass

    # PTY wrapper mode: kubectl-colorize [--no-color] -- <command> [args...]
    if '--' in args:
        sep = args.index('--')
        cmd = args[sep + 1:]
        if not cmd:
            print("kubectl-colorize: missing command after --", file=sys.stderr)
            sys.exit(1)
        run_pty(cmd, no_color)
    else:
        # Filter mode
        run_filter(no_color)


if __name__ == '__main__':
    main()

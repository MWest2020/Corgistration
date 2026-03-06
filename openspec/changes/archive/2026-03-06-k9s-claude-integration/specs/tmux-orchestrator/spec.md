## ADDED Requirements

### Requirement: Session reuse or creation
The orchestrator SHALL check for an existing tmux session named `corgistration`. If it exists, it SHALL reuse it and update the pane contents. If it does not exist, it SHALL create a new session with the required pane layout.

#### Scenario: First invocation creates session
- **WHEN** no tmux session named `corgistration` exists
- **THEN** the orchestrator creates a new detached session, splits it into the required pane layout, and attaches or switches to it

#### Scenario: Subsequent invocation reuses session
- **WHEN** a `corgistration` tmux session already exists
- **THEN** the orchestrator sends new content to the existing panes without creating a new session or disrupting the user's active tmux layout

### Requirement: Two-pane layout
The session SHALL maintain a horizontal split with:
- **Left pane** (≥50% width): TUI renderer output (read-only display)
- **Right pane** (≤50% width): Claude Code interactive shell

#### Scenario: Pane proportions on creation
- **WHEN** the orchestrator creates a new session
- **THEN** the left pane occupies 55% of terminal width and the right pane occupies 45%

### Requirement: Pane independence
The two panes SHALL be independent shell processes. A crash or exit in the right (Claude) pane MUST NOT kill the left (TUI) pane, and vice versa.

#### Scenario: Claude pane exits cleanly
- **WHEN** the user exits Claude Code in the right pane
- **THEN** the left pane remains visible with the last rendered context, and the right pane returns to a shell prompt

### Requirement: Context file path passed to both panes
The orchestrator SHALL pass the path to the collected context temp file to both the TUI renderer and the Claude invoker as an argument or environment variable.

#### Scenario: Both panes receive the same context
- **WHEN** the orchestrator launches after context collection
- **THEN** both panes reference the same temp file path, ensuring consistency between what the user reads and what Claude analyzes

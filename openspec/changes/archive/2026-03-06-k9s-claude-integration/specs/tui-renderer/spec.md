## ADDED Requirements

### Requirement: Syntax-highlighted YAML rendering
The renderer SHALL display the YAML MANIFEST section with syntax highlighting. If `bat` is available, it SHALL be used with `--language=yaml`. If `bat` is unavailable, it SHALL fall back to plain output with a warning.

#### Scenario: bat available
- **WHEN** `bat` is on PATH and the renderer displays the YAML section
- **THEN** output includes ANSI color codes for YAML keys, values, and structure

#### Scenario: bat unavailable
- **WHEN** `bat` is not on PATH
- **THEN** the YAML section is displayed as plain text with a one-line notice: `(install bat for syntax highlighting)`

### Requirement: Log level colorization
The renderer SHALL colorize log lines by severity in the LOGS section:
- Lines containing `ERROR` or `FATAL` → red
- Lines containing `WARN` or `WARNING` → yellow
- Lines containing `INFO` or `DEBUG` → default terminal color

#### Scenario: Error log line highlighted
- **WHEN** a log line contains the token `ERROR`
- **THEN** that line is rendered in red ANSI color

#### Scenario: Mixed severity log block
- **WHEN** a log block contains ERROR, WARN, and INFO lines
- **THEN** each line is independently colorized by its severity level

### Requirement: Event warning prominence
In the EVENTS section, lines containing `Warning` (Kubernetes event type) SHALL be rendered in yellow and prefixed with a `!` indicator. `Normal` event lines SHALL be dimmed.

#### Scenario: Warning event surfaced
- **WHEN** an event line begins with `Warning`
- **THEN** it is rendered in yellow with a leading `! ` prefix

#### Scenario: Normal event dimmed
- **WHEN** an event line begins with `Normal`
- **THEN** it is rendered with dim ANSI styling

### Requirement: Section headers clearly delineated
Section headers (`=== YAML MANIFEST ===`, `=== EVENTS ===`, `=== LOGS ===`) SHALL be rendered in bold cyan to visually separate sections.

#### Scenario: Section header styling
- **WHEN** the renderer encounters a line matching the `=== ... ===` pattern
- **THEN** it outputs that line in bold cyan ANSI escape codes

### Requirement: Pager for long output
If the rendered output exceeds the terminal height, the renderer SHALL pipe through `less -R` to allow scrolling without losing color codes.

#### Scenario: Output longer than terminal
- **WHEN** rendered output line count exceeds `$LINES`
- **THEN** output is piped to `less -R` automatically

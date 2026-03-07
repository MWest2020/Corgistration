## ADDED Requirements

### Requirement: Direct invocation mode
When invoked as `corgi <Kind> <name> <namespace>`, the binary SHALL validate the three positional arguments, collect context for that resource, and launch the tmux diagnostic layout. Kind is case-insensitive.

#### Scenario: Valid direct invocation
- **WHEN** user runs `corgi Pod api-server default`
- **THEN** the binary collects context for `Pod/api-server` in namespace `default` and launches the tmux split

#### Scenario: Missing arguments in direct mode
- **WHEN** user runs `corgi Pod api-server` (missing namespace)
- **THEN** the binary prints a usage error to stderr and exits 1

### Requirement: Interactive TUI mode
When invoked with no positional arguments, the binary SHALL launch the bubbletea resource picker TUI.

#### Scenario: No-arg invocation launches picker
- **WHEN** user runs `corgi` with no arguments
- **THEN** the interactive resource picker opens in the terminal

#### Scenario: Namespace filter applied to picker
- **WHEN** user runs `corgi -n staging`
- **THEN** the picker shows only resources in the `staging` namespace

### Requirement: --context flag
The `--context` flag SHALL override the kubeconfig context used for all kubectl and client-go calls in that invocation.

#### Scenario: Context override respected
- **WHEN** user runs `corgi --context prod-cluster`
- **THEN** all cluster API calls use the `prod-cluster` kubeconfig context

### Requirement: --version flag
`corgi --version` SHALL print the version string in the format `corgi vX.Y.Z (commit <sha>)` and exit 0.

#### Scenario: Version output
- **WHEN** user runs `corgi --version`
- **THEN** stdout contains `corgi v` followed by a semver string and exits 0

### Requirement: Secret resource blocked
If the user passes `Kind=Secret` in direct mode, the binary SHALL print an error to stderr and exit 2 without collecting any data.

#### Scenario: Secret blocked
- **WHEN** user runs `corgi Secret my-secret default`
- **THEN** stderr contains "Secret resources are excluded to prevent credential exposure" and process exits 2

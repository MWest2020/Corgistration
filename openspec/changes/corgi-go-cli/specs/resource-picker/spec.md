## ADDED Requirements

### Requirement: Resource list display
The picker SHALL display Pods, Deployments, and Services from the cluster in a scrollable list. Each row SHALL show: resource type (color-coded), name, namespace, and status/ready field.

#### Scenario: Resources loaded and displayed
- **WHEN** the picker opens
- **THEN** a scrollable list shows all Pods, Deployments, and Services from all namespaces (or the filtered namespace), each with kind, name, namespace, and status

#### Scenario: Empty cluster
- **WHEN** no Pods, Deployments, or Services exist in the target namespace
- **THEN** the picker displays a "no resources found" message and does not crash

### Requirement: Keyboard navigation
The picker SHALL support arrow keys (up/down) or j/k for navigation, Enter to select, q or Ctrl-C to quit without action, and / to open an inline filter.

#### Scenario: Select resource with Enter
- **WHEN** user navigates to a row and presses Enter
- **THEN** the TUI closes and the diagnostic flow fires for that resource

#### Scenario: Quit without action
- **WHEN** user presses q or Ctrl-C
- **THEN** the process exits 0 with no diagnostic flow triggered

#### Scenario: Inline filter
- **WHEN** user presses / and types a string
- **THEN** the list filters to rows whose name or namespace contains that string (case-insensitive)

### Requirement: Color-coded resource types
Each resource type SHALL be rendered in a distinct color using lipgloss: Pods in green, Deployments in cyan, Services in yellow.

#### Scenario: Pod row color
- **WHEN** a Pod row is displayed
- **THEN** the "Pod" type label is rendered in green

### Requirement: Status indicators
Pod rows SHALL show a visual indicator of readiness: a green dot for Running/Ready, yellow for Pending, red for CrashLoopBackOff or Failed.

#### Scenario: CrashLoopBackOff indicated
- **WHEN** a Pod is in CrashLoopBackOff
- **THEN** its row shows a red indicator and the status text

### Requirement: Loading state
While the resource list is being fetched from the cluster, the picker SHALL display a spinner and "Fetching resources…" message rather than an empty or broken list.

#### Scenario: Loading spinner shown
- **WHEN** the picker opens and the cluster API call is in flight
- **THEN** a spinner animation is visible until results arrive

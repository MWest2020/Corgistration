## ADDED Requirements

### Requirement: Parallel collection via goroutines
The Go collector SHALL run YAML manifest, events, and log collection concurrently using goroutines and sync.WaitGroup (or errgroup). Total wall-clock time SHALL be bounded by the slowest single call, not their sum.

#### Scenario: Three sections collected in parallel
- **WHEN** `CollectContext` is called for a Pod
- **THEN** kubectl get -o yaml, kubectl describe, and kubectl logs run concurrently and all results are available when the function returns

#### Scenario: Deployment skips log collection
- **WHEN** `CollectContext` is called for a Deployment
- **THEN** only YAML manifest and describe/events are collected; the LOGS section contains a note that logs are not applicable

### Requirement: Per-section error isolation
If one collection goroutine fails, its error message SHALL be written into that section's content. Other sections SHALL complete normally.

#### Scenario: Log collection RBAC denied
- **WHEN** the user lacks log access and YAML/events succeed
- **THEN** the temp file contains valid YAML and events sections, and the LOGS section contains the kubectl error text

### Requirement: Timeout per collection call
Each kubectl exec call SHALL be wrapped with a configurable timeout (default 10s). A timed-out call SHALL write a timeout error into that section rather than hanging indefinitely.

#### Scenario: Slow node causes log timeout
- **WHEN** kubectl logs does not respond within the timeout
- **THEN** the LOGS section contains "context deadline exceeded" and collection returns without hanging

### Requirement: Structured output format
The output file SHALL use the same section header format as the existing shell collector so render.sh and claude-invoke.sh remain compatible:
```
=== YAML MANIFEST ===
=== EVENTS ===
=== LOGS ===
```

#### Scenario: Output compatible with render.sh
- **WHEN** the Go collector writes a context file
- **THEN** render.sh processes it without modification and produces colored output

### Requirement: Secret resource guard
If called with Kind=Secret, the function SHALL return an error immediately without executing any kubectl call.

#### Scenario: Secret blocked at collector
- **WHEN** CollectContext is called with kind="Secret"
- **THEN** it returns an error containing "Secret resources are excluded" and no kubectl calls are made

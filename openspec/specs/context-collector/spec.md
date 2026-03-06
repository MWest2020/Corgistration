## ADDED Requirements

### Requirement: Parallel context collection
The collector SHALL gather logs, YAML manifest, and events for the target resource concurrently using background subshells, then write all three sections to a single structured temp file. Total collection time SHALL be bounded by the slowest individual `kubectl` call, not the sum.

#### Scenario: Pod context collected in parallel
- **WHEN** the collector is invoked with `kind=Pod name=api-server namespace=default`
- **THEN** it runs `kubectl logs`, `kubectl get pod -o yaml`, and `kubectl describe pod` concurrently, then writes all output to a temp file before returning

#### Scenario: Deployment context omits log collection
- **WHEN** the collector is invoked with `kind=Deployment`
- **THEN** it collects YAML manifest and events via `kubectl describe`, and skips the log step (logs belong to Pods, not Deployments)

### Requirement: Structured output format
The temp file SHALL use labeled section headers so downstream consumers (TUI renderer, Claude invoker) can parse each section independently. Format:

```
=== YAML MANIFEST ===
<kubectl get -o yaml output>
=== EVENTS ===
<kubectl describe events section>
=== LOGS ===
<kubectl logs output, omitted if not applicable>
```

#### Scenario: Sections always present
- **WHEN** context collection completes for any resource type
- **THEN** the temp file contains all applicable section headers, with empty bodies for sections not relevant to that resource type

### Requirement: Graceful handling of missing or inaccessible resources
If a `kubectl` call fails (resource not found, RBAC denied, timeout), the collector SHALL write the error message into the corresponding section rather than aborting the entire collection.

#### Scenario: Log collection RBAC denied
- **WHEN** the user lacks `get pods/log` permission
- **THEN** the LOGS section contains the kubectl error message and collection continues for other sections

#### Scenario: Resource not found
- **WHEN** the resource has been deleted between selection and collection
- **THEN** all sections contain the `not found` error and the collector exits cleanly with a non-zero status

### Requirement: No credential storage
The collector SHALL use only the user's ambient `KUBECONFIG` environment variable (defaulting to `~/.kube/config`). It MUST NOT write, read, or cache credentials anywhere.

#### Scenario: Custom KUBECONFIG honored
- **WHEN** the user has `KUBECONFIG=/path/to/custom/config` set in their environment
- **THEN** all kubectl calls in the collector use that config without any additional configuration

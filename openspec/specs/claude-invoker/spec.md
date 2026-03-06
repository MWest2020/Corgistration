## ADDED Requirements

### Requirement: Context pre-loaded as initial prompt
The invoker SHALL compose an initial prompt that includes: the resource kind, name, namespace, and the full collected context from the temp file. It SHALL then launch `claude` CLI in interactive mode with this prompt so the user lands directly in a diagnostic conversation.

#### Scenario: Claude receives full resource context
- **WHEN** the invoker is called with `kind=Pod name=api-server namespace=default` and a context file path
- **THEN** `claude` is started with an initial message containing the resource identity and full YAML/logs/events context, and the user is dropped into an interactive Claude session

#### Scenario: Context too large for single prompt
- **WHEN** the context file exceeds a configurable line threshold (default: 500 lines)
- **THEN** the invoker truncates logs to the last N lines (default: 100) and events to the last N entries (default: 20), prepending a notice that truncation occurred

### Requirement: Diagnostic framing in system prompt
The invoker SHALL pass a system prompt to `claude` instructing it to act as a Kubernetes diagnostic expert: identify the problem, explain the root cause, and suggest a concrete fix or next investigative step.

#### Scenario: Diagnosis framing present
- **WHEN** Claude is launched by the invoker
- **THEN** Claude's first response addresses the resource's health, identifies any visible issues, and proposes a remediation or next step

### Requirement: Interactive follow-up enabled
After the initial diagnosis, the user SHALL be able to continue the conversation interactively in the same Claude session (ask follow-up questions, request `kubectl` commands, ask to generate a patch).

#### Scenario: Follow-up question answered
- **WHEN** the user types a follow-up question after Claude's initial diagnosis
- **THEN** Claude responds in the context of the already-loaded resource information

### Requirement: No secrets in prompt or temp file
The invoker MUST NOT include kubeconfig tokens, certificates, or passwords in the prompt or temp file. The collected context is limited to what `kubectl get/logs/describe` outputs, which does not include secret values.

#### Scenario: Secret resource type excluded
- **WHEN** the user triggers the hotkey on a `Secret` resource
- **THEN** the invoker refuses to collect or forward that context and displays a warning: `Secret resources are excluded to prevent credential exposure`

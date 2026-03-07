## MODIFIED Requirements

### Requirement: Hotkey registration per resource type
The plugin SHALL register a configurable hotkey (default `shift-a`) in `~/.config/k9s/plugins.yaml` for each supported resource type: Pod, Deployment, and Service. The plugin entry MUST invoke the `corgi` binary (not `corgistration.sh`), passing the resource name, namespace, and resource kind as positional arguments.

#### Scenario: Hotkey fires for a Pod
- **WHEN** the user highlights a Pod row in K9s and presses the registered hotkey
- **THEN** K9s executes `corgi Pod $NAME $NAMESPACE`

#### Scenario: Hotkey fires for a Deployment
- **WHEN** the user highlights a Deployment row in K9s and presses the registered hotkey
- **THEN** K9s executes `corgi Deployment $NAME $NAMESPACE`

#### Scenario: Hotkey fires for a Service
- **WHEN** the user highlights a Service row in K9s and presses the registered hotkey
- **THEN** K9s executes `corgi Service $NAME $NAMESPACE`

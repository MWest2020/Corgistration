## ADDED Requirements

### Requirement: Hotkey registration per resource type
The plugin SHALL register a configurable hotkey (default `shift-a`) in `~/.config/k9s/plugins.yaml` for each supported resource type: Pod, Deployment, and Service. The plugin entry MUST invoke the corgistration entry-point script, passing the resource name, namespace, and resource kind as arguments.

#### Scenario: Hotkey fires for a Pod
- **WHEN** the user highlights a Pod row in K9s and presses the registered hotkey
- **THEN** K9s executes the plugin shell command with `kind=Pod`, `name=<pod-name>`, and `namespace=<namespace>` as arguments

#### Scenario: Hotkey fires for a Deployment
- **WHEN** the user highlights a Deployment row in K9s and presses the registered hotkey
- **THEN** K9s executes the plugin shell command with `kind=Deployment`, `name=<deployment-name>`, and `namespace=<namespace>` as arguments

#### Scenario: Hotkey fires for a Service
- **WHEN** the user highlights a Service row in K9s and presses the registered hotkey
- **THEN** K9s executes the plugin shell command with `kind=Service`, `name=<service-name>`, and `namespace=<namespace>` as arguments

### Requirement: Plugin is non-destructive on install
Installing the plugin configuration SHALL append to an existing `plugins.yaml` without overwriting unrelated plugin entries. If no `plugins.yaml` exists, it SHALL be created.

#### Scenario: Existing plugins preserved
- **WHEN** the user already has entries in `~/.config/k9s/plugins.yaml`
- **THEN** the install script adds corgistration entries without removing or altering existing entries

#### Scenario: Fresh install creates config
- **WHEN** no `~/.config/k9s/plugins.yaml` exists
- **THEN** the install script creates the file with corgistration plugin entries only

### Requirement: Plugin passes current kubeconfig context
The plugin command MUST NOT hard-code a namespace or kubeconfig path. It SHALL rely on K9s's `$NAMESPACE` and `$NAME` shell variables and the user's active `KUBECONFIG` environment.

#### Scenario: Correct namespace forwarded
- **WHEN** the user is viewing resources in namespace `staging` and triggers the hotkey
- **THEN** the plugin passes `staging` as the namespace argument to the entry-point script

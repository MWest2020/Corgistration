## ADDED Requirements

### Requirement: Matrix build for four targets
The GitHub Actions release workflow SHALL build the `corgi` binary for linux/amd64, linux/arm64, darwin/amd64, and darwin/arm64 using `GOOS`/`GOARCH` env vars. Each artifact SHALL be named `corgi-<os>-<arch>`.

#### Scenario: Tag push triggers release builds
- **WHEN** a tag matching `v*` is pushed to the repository
- **THEN** GitHub Actions builds all four binaries and attaches them to a GitHub Release

#### Scenario: Binary naming convention
- **WHEN** the linux/amd64 binary is produced
- **THEN** it is named `corgi-linux-amd64` in the release assets

### Requirement: Stripped static binary
Binaries SHALL be built with `CGO_ENABLED=0` and `-ldflags="-s -w"` to produce small, statically linked binaries with no external runtime dependencies.

#### Scenario: Binary has no dynamic dependencies
- **WHEN** `ldd corgi-linux-amd64` is run
- **THEN** output is "not a dynamic executable"

### Requirement: Version baked in at build time
The build SHALL inject the git tag and short commit SHA into the binary via ldflags so `corgi --version` reports them accurately.

#### Scenario: Version reflects release tag
- **WHEN** binary is built from tag v0.2.0 at commit abc1234
- **THEN** `corgi --version` prints `corgi v0.2.0 (commit abc1234)`

### Requirement: Checksum file published
The release SHALL include a `checksums.txt` file with SHA-256 hashes for all binary artifacts.

#### Scenario: Checksum file present
- **WHEN** a GitHub Release is published
- **THEN** `checksums.txt` is attached alongside the binaries

### Requirement: get.sh downloads correct binary
`get.sh` SHALL be updated to detect the OS and architecture, download the matching binary from the latest GitHub Release, verify its checksum, and install it to `~/.local/bin/corgi`.

#### Scenario: Linux amd64 install
- **WHEN** get.sh runs on a linux/amd64 machine
- **THEN** it downloads `corgi-linux-amd64`, verifies the SHA-256 checksum, and installs it as `~/.local/bin/corgi`

#### Scenario: Checksum mismatch aborts install
- **WHEN** the downloaded binary does not match the checksum in checksums.txt
- **THEN** get.sh prints an error, removes the downloaded file, and exits 1

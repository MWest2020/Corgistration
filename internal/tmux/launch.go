package tmux

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// Launch calls orchestrate.sh with the collected context file and resource identity.
// It inherits stdin/stdout/stderr so tmux can attach correctly.
func Launch(contextFile, kind, name, namespace string) error {
	if err := requireCmd("tmux"); err != nil {
		return err
	}

	orchestrate, err := findScript("orchestrate.sh")
	if err != nil {
		return err
	}

	cmd := exec.Command(orchestrate, contextFile, kind, name, namespace)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("orchestrate.sh: %w", err)
	}
	return nil
}

// findScript looks for a script in ~/.local/bin first, then $PATH.
func findScript(name string) (string, error) {
	// Check ~/.local/bin first
	home, err := os.UserHomeDir()
	if err == nil {
		candidate := filepath.Join(home, ".local", "bin", name)
		if _, err := os.Stat(candidate); err == nil {
			return candidate, nil
		}
	}

	// Fall back to PATH
	path, err := exec.LookPath(name)
	if err != nil {
		return "", fmt.Errorf(
			"%s not found in ~/.local/bin or PATH\n"+
				"  Run the installer first: curl -fsSL https://raw.githubusercontent.com/MWest2020/Corgistration/main/get.sh | bash",
			name,
		)
	}
	return path, nil
}

// requireCmd checks that a command exists on PATH.
func requireCmd(name string) error {
	if _, err := exec.LookPath(name); err != nil {
		return fmt.Errorf(
			"'%s' is required but not found on PATH.\n"+
				"  Install: https://github.com/tmux/tmux",
			name,
		)
	}
	return nil
}

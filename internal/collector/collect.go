package collector

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

const defaultTimeout = 10 * time.Second

// CollectContext gathers YAML manifest, events, and logs for a K8s resource
// in parallel and writes them to a temp file. Returns the temp file path.
// Pass timeout=0 to use the default (10s per call).
func CollectContext(kind, name, namespace, kubeContext string, timeout time.Duration) (string, error) {
	if strings.EqualFold(kind, "secret") {
		return "", fmt.Errorf("Secret resources are excluded to prevent credential exposure")
	}

	if timeout == 0 {
		timeout = defaultTimeout
	}

	// Collect all three sections in parallel
	var (
		yamlOut, eventsOut, logsOut string
		wg                          sync.WaitGroup
	)

	wg.Add(3)

	go func() {
		defer wg.Done()
		yamlOut = runKubectl(kubeContext, timeout,
			"get", strings.ToLower(kind), name,
			"--namespace", namespace,
			"--output", "yaml",
		)
	}()

	go func() {
		defer wg.Done()
		eventsOut = runKubectl(kubeContext, timeout,
			"describe", strings.ToLower(kind), name,
			"--namespace", namespace,
		)
	}()

	go func() {
		defer wg.Done()
		if strings.EqualFold(kind, "pod") {
			logsOut = runKubectl(kubeContext, timeout,
				"logs", name,
				"--namespace", namespace,
				"--tail", "200",
				"--timestamps",
			)
		} else {
			logsOut = fmt.Sprintf("(log collection not applicable for %s resources)\n", kind)
		}
	}()

	wg.Wait()

	// Write structured output to temp file
	tmp, err := os.CreateTemp("", "corgistration-*.txt")
	if err != nil {
		return "", fmt.Errorf("create temp file: %w", err)
	}
	defer tmp.Close()

	fmt.Fprintf(tmp, "=== YAML MANIFEST ===\n%s\n", yamlOut)
	fmt.Fprintf(tmp, "=== EVENTS ===\n%s\n", eventsOut)
	fmt.Fprintf(tmp, "=== LOGS ===\n%s\n", logsOut)

	return tmp.Name(), nil
}

// runKubectl runs a kubectl command with a timeout and returns combined stdout+stderr.
// On failure the error message is returned as the output so the section is never empty.
func runKubectl(kubeContext string, timeout time.Duration, args ...string) string {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	if kubeContext != "" {
		args = append([]string{"--context", kubeContext}, args...)
	}

	cmd := exec.CommandContext(ctx, "kubectl", args...)

	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	if err := cmd.Run(); err != nil {
		errMsg := stderr.String()
		if errMsg == "" {
			errMsg = err.Error()
		}
		return fmt.Sprintf("Error: %s\n", strings.TrimSpace(errMsg))
	}

	return stdout.String()
}

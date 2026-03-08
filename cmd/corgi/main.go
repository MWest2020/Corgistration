package main

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/MWest2020/Corgistration/internal/collector"
	"github.com/MWest2020/Corgistration/internal/picker"
	"github.com/MWest2020/Corgistration/internal/tmux"
	"github.com/spf13/cobra"
	"golang.org/x/term"
)

// Injected at build time via -ldflags.
var (
	version = "dev"
	commit  = "none"
)

func main() {
	if err := newRootCmd().Execute(); err != nil {
		os.Exit(1)
	}
}

func newRootCmd() *cobra.Command {
	var namespace string
	var kubeContext string

	root := &cobra.Command{
		Use:   "corgi [kind name namespace]",
		Short: "K9s + Claude Code + tmux diagnostic integration",
		Long: `corgi diagnoses Kubernetes resources using Claude Code.

With no arguments, an interactive picker lets you choose any
Pod, Deployment, or Service from your cluster.

With three arguments, it diagnoses that specific resource directly:
  corgi Pod api-server default`,
		Args: cobra.MaximumNArgs(3),
		RunE: func(cmd *cobra.Command, args []string) error {
			// Print version and exit
			if cmd.Flags().Changed("version") {
				fmt.Printf("corgi v%s (commit %s)\n", version, commit)
				return nil
			}

			var kind, name, ns string

			if len(args) == 3 {
				// Direct invocation mode
				kind, name, ns = args[0], args[1], args[2]
			} else if len(args) > 0 {
				return errors.New("direct mode requires exactly 3 arguments: corgi <kind> <name> <namespace>")
			} else {
				// Interactive picker mode — requires a TTY
				if !term.IsTerminal(int(os.Stdin.Fd())) {
					return errors.New("interactive picker requires a TTY.\nUsage: corgi <kind> <name> <namespace>")
				}
				result, err := picker.Run(picker.Config{
					Namespace:   namespace,
					KubeContext: kubeContext,
				})
				if err != nil {
					return fmt.Errorf("picker: %w", err)
				}
				if result == nil {
					// User quit without selecting
					return nil
				}
				kind, name, ns = result.Kind, result.Name, result.Namespace
			}

			// Override namespace if flag was set and we're in direct mode
			if cmd.Flags().Changed("namespace") && len(args) == 3 {
				ns = namespace
			}

			return diagnose(kind, name, ns, kubeContext)
		},
	}

	root.Flags().StringVarP(&namespace, "namespace", "n", "", "filter resources by namespace")
	root.Flags().StringVar(&kubeContext, "context", "", "override kubeconfig context")
	root.Flags().BoolP("version", "v", false, "print version and exit")

	return root
}

// diagnose collects context for a resource and launches the tmux diagnostic layout.
func diagnose(kind, name, ns, kubeContext string) error {
	if strings.EqualFold(kind, "secret") {
		fmt.Fprintln(os.Stderr, "Error: Secret resources are excluded to prevent credential exposure")
		os.Exit(2)
	}

	fmt.Printf("Collecting context for %s/%s in namespace %s…\n", kind, name, ns)

	contextFile, err := collector.CollectContext(kind, name, ns, kubeContext, 0)
	if err != nil {
		return fmt.Errorf("context collection failed: %w", err)
	}

	return tmux.Launch(contextFile, kind, name, ns)
}

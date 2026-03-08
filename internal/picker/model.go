package picker

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"sync"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

// Config holds options for the picker.
type Config struct {
	Namespace   string
	KubeContext string
}

// Resource is a selectable K8s resource.
type Resource struct {
	Kind      string
	Name      string
	Namespace string
	Status    string
}

// kindOrder defines display order for kind grouping.
var kindOrder = map[string]int{
	"Deployment":  0,
	"StatefulSet": 1,
	"Pod":         2,
	"Service":     3,
}

func kindRank(k string) int {
	if r, ok := kindOrder[k]; ok {
		return r
	}
	return 99
}

// styles
var (
	stylePod        = lipgloss.NewStyle().Foreground(lipgloss.Color("2")).Bold(true)  // green
	styleDeployment = lipgloss.NewStyle().Foreground(lipgloss.Color("6")).Bold(true)  // cyan
	styleService    = lipgloss.NewStyle().Foreground(lipgloss.Color("3")).Bold(true)  // yellow
	styleStateful   = lipgloss.NewStyle().Foreground(lipgloss.Color("5")).Bold(true)  // magenta
	styleSelected   = lipgloss.NewStyle().Background(lipgloss.Color("4")).Foreground(lipgloss.Color("15")).Bold(true)
	styleDim        = lipgloss.NewStyle().Faint(true)
	styleError      = lipgloss.NewStyle().Foreground(lipgloss.Color("1"))
	styleHeader     = lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Bold(true)

	dotGreen  = lipgloss.NewStyle().Foreground(lipgloss.Color("2")).Render("●")
	dotYellow = lipgloss.NewStyle().Foreground(lipgloss.Color("3")).Render("●")
	dotRed    = lipgloss.NewStyle().Foreground(lipgloss.Color("1")).Render("●")
)

// Messages
type resourcesLoadedMsg struct{ resources []Resource }
type errMsg struct{ err error }

// model is the bubbletea model.
type model struct {
	config      Config
	resources   []Resource
	filtered    []Resource
	cursor      int
	loading     bool
	err         error
	selected    *Resource
	quitting    bool
	filterMode  bool
	filterInput textinput.Model
	spinner     spinner.Model
}

func initialModel(cfg Config) model {
	ti := textinput.New()
	ti.Placeholder = "filter…"
	ti.CharLimit = 64

	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("6"))

	return model{
		config:      cfg,
		loading:     true,
		filterInput: ti,
		spinner:     sp,
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		fetchResources(m.config),
	)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {

	case resourcesLoadedMsg:
		m.loading = false
		m.resources = msg.resources
		m.filtered = msg.resources
		m.cursor = 0
		return m, nil

	case errMsg:
		m.loading = false
		m.err = msg.err
		return m, nil

	case spinner.TickMsg:
		if m.loading {
			var cmd tea.Cmd
			m.spinner, cmd = m.spinner.Update(msg)
			return m, cmd
		}

	case tea.KeyMsg:
		if m.filterMode {
			switch msg.String() {
			case "esc", "/":
				m.filterMode = false
				m.filterInput.Blur()
			case "enter":
				m.filterMode = false
				m.filterInput.Blur()
			default:
				var cmd tea.Cmd
				m.filterInput, cmd = m.filterInput.Update(msg)
				m.applyFilter()
				return m, cmd
			}
			return m, nil
		}

		switch msg.String() {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.filtered)-1 {
				m.cursor++
			}
		case "enter":
			if len(m.filtered) > 0 {
				r := m.filtered[m.cursor]
				m.selected = &r
				return m, tea.Quit
			}
		case "/":
			m.filterMode = true
			m.filterInput.Focus()
		}
	}

	return m, nil
}

func (m *model) applyFilter() {
	q := strings.ToLower(m.filterInput.Value())
	if q == "" {
		m.filtered = m.resources
		m.cursor = 0
		return
	}
	var out []Resource
	for _, r := range m.resources {
		if strings.Contains(strings.ToLower(r.Name), q) ||
			strings.Contains(strings.ToLower(r.Namespace), q) ||
			strings.Contains(strings.ToLower(r.Kind), q) {
			out = append(out, r)
		}
	}
	m.filtered = out
	m.cursor = 0
}

func (m model) View() string {
	if m.loading {
		return fmt.Sprintf("\n  %s Fetching resources…\n\n  %s",
			m.spinner.View(),
			styleDim.Render("ctrl+c to cancel"),
		)
	}
	if m.err != nil {
		return styleError.Render(fmt.Sprintf("\n  Error: %v\n", m.err))
	}
	if m.quitting {
		return ""
	}

	var b strings.Builder
	b.WriteString("\n")
	b.WriteString("  ")
	b.WriteString(lipgloss.NewStyle().Bold(true).Render("C O R G I S T R A T I O N"))
	b.WriteString("  —  select a resource to diagnose\n\n")

	if len(m.filtered) == 0 {
		b.WriteString(styleDim.Render("  no resources found\n"))
	}

	var lastKind string
	for i, r := range m.filtered {
		// Section header when kind changes
		if r.Kind != lastKind {
			if lastKind != "" {
				b.WriteString("\n")
			}
			b.WriteString(styleHeader.Render(fmt.Sprintf("  ── %s ", strings.ToUpper(r.Kind)+"S")) + "\n")
			lastKind = r.Kind
		}

		dot := statusDot(r)
		kindLabel := kindStyle(r.Kind).Render(fmt.Sprintf("%-12s", r.Kind))
		if i == m.cursor {
			row := fmt.Sprintf("► %s %-40s %-20s %s", kindLabel, r.Name, r.Namespace, dot+" "+r.Status)
			b.WriteString(styleSelected.Render(row))
		} else {
			row := fmt.Sprintf("  %s %-40s %-20s %s", kindLabel, r.Name, r.Namespace, dot+" "+r.Status)
			b.WriteString(row)
		}
		b.WriteString("\n")
	}

	b.WriteString("\n")
	if m.filterMode {
		b.WriteString("  / " + m.filterInput.View() + "\n")
	} else {
		b.WriteString(styleDim.Render("  ↑/↓ navigate  enter select  / filter  q quit") + "\n")
	}

	return b.String()
}

func kindStyle(kind string) lipgloss.Style {
	switch strings.ToLower(kind) {
	case "pod":
		return stylePod
	case "deployment":
		return styleDeployment
	case "statefulset":
		return styleStateful
	default:
		return styleService
	}
}

func statusDot(r Resource) string {
	s := strings.ToLower(r.Status)
	switch {
	case strings.Contains(s, "running") || strings.Contains(s, "ready"):
		return dotGreen
	case strings.Contains(s, "pending"):
		return dotYellow
	case strings.Contains(s, "crash"), strings.Contains(s, "failed"), strings.Contains(s, "error"):
		return dotRed
	default:
		return dotYellow
	}
}

// fetchResources is a tea.Cmd that loads resources from the cluster.
func fetchResources(cfg Config) tea.Cmd {
	return func() tea.Msg {
		resources, err := loadResources(cfg)
		if err != nil {
			return errMsg{err}
		}
		return resourcesLoadedMsg{resources}
	}
}

func loadResources(cfg Config) ([]Resource, error) {
	loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
	overrides := &clientcmd.ConfigOverrides{}
	if cfg.KubeContext != "" {
		overrides.CurrentContext = cfg.KubeContext
	}
	clientConfig := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(loadingRules, overrides)
	restConfig, err := clientConfig.ClientConfig()
	if err != nil {
		return nil, fmt.Errorf("build kubeconfig: %w", err)
	}

	cs, err := kubernetes.NewForConfig(restConfig)
	if err != nil {
		return nil, fmt.Errorf("build client: %w", err)
	}

	ns := cfg.Namespace

	var (
		resources []Resource
		mu        sync.Mutex
		wg        sync.WaitGroup
		fetchErr  error
	)

	wg.Add(4)

	go func() {
		defer wg.Done()
		deps, err := cs.AppsV1().Deployments(ns).List(context.Background(), metav1.ListOptions{})
		if err != nil {
			return
		}
		mu.Lock()
		for _, d := range deps.Items {
			status := fmt.Sprintf("%d/%d ready", d.Status.ReadyReplicas, d.Status.Replicas)
			resources = append(resources, Resource{
				Kind:      "Deployment",
				Name:      d.Name,
				Namespace: d.Namespace,
				Status:    status,
			})
		}
		mu.Unlock()
	}()

	go func() {
		defer wg.Done()
		sets, err := cs.AppsV1().StatefulSets(ns).List(context.Background(), metav1.ListOptions{})
		if err != nil {
			return
		}
		mu.Lock()
		for _, s := range sets.Items {
			status := fmt.Sprintf("%d/%d ready", s.Status.ReadyReplicas, s.Status.Replicas)
			resources = append(resources, Resource{
				Kind:      "StatefulSet",
				Name:      s.Name,
				Namespace: s.Namespace,
				Status:    status,
			})
		}
		mu.Unlock()
	}()

	go func() {
		defer wg.Done()
		pods, err := cs.CoreV1().Pods(ns).List(context.Background(), metav1.ListOptions{})
		if err != nil {
			mu.Lock()
			fetchErr = err
			mu.Unlock()
			return
		}
		mu.Lock()
		for _, p := range pods.Items {
			resources = append(resources, Resource{
				Kind:      "Pod",
				Name:      p.Name,
				Namespace: p.Namespace,
				Status:    podStatus(p),
			})
		}
		mu.Unlock()
	}()

	go func() {
		defer wg.Done()
		svcs, err := cs.CoreV1().Services(ns).List(context.Background(), metav1.ListOptions{})
		if err != nil {
			return
		}
		mu.Lock()
		for _, s := range svcs.Items {
			resources = append(resources, Resource{
				Kind:      "Service",
				Name:      s.Name,
				Namespace: s.Namespace,
				Status:    string(s.Spec.Type),
			})
		}
		mu.Unlock()
	}()

	wg.Wait()

	if fetchErr != nil {
		return nil, fetchErr
	}

	// Sort by kind rank then name so list is grouped and stable
	sort.Slice(resources, func(i, j int) bool {
		ri, rj := resources[i], resources[j]
		if kindRank(ri.Kind) != kindRank(rj.Kind) {
			return kindRank(ri.Kind) < kindRank(rj.Kind)
		}
		if ri.Namespace != rj.Namespace {
			return ri.Namespace < rj.Namespace
		}
		return ri.Name < rj.Name
	})

	return resources, nil
}

func podStatus(p corev1.Pod) string {
	for _, cs := range p.Status.ContainerStatuses {
		if cs.State.Waiting != nil {
			return cs.State.Waiting.Reason
		}
	}
	return string(p.Status.Phase)
}

// satisfy unused import (appsv1 used via StatefulSet/Deployment above indirectly through client-go)
var _ = appsv1.Deployment{}

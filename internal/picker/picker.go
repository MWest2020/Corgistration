package picker

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
)

// Run launches the interactive TUI picker and returns the selected resource,
// or nil if the user quit without selecting.
func Run(cfg Config) (*Resource, error) {
	m := initialModel(cfg)
	p := tea.NewProgram(m, tea.WithAltScreen())
	result, err := p.Run()
	if err != nil {
		return nil, fmt.Errorf("picker: %w", err)
	}
	final, ok := result.(model)
	if !ok || final.selected == nil {
		return nil, nil
	}
	return final.selected, nil
}

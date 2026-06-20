package monitor

// MockProvider returns deterministic metrics for testing.
type MockProvider struct {
	tick int
}

// NewMockProvider creates a mock provider at tick 0.
func NewMockProvider() *MockProvider {
	return &MockProvider{}
}

// AdvanceTick moves to the next predetermined snapshot.
func (m *MockProvider) AdvanceTick() {
	m.tick++
}

// CPUPercent returns the CPU percentage for the current tick.
func (m *MockProvider) CPUPercent() float64 {
	switch m.tick {
	case 0:
		return 45.2
	case 1:
		return 52.3
	default:
		return 38.7
	}
}

// MEMPercent returns the memory percentage for the current tick.
func (m *MockProvider) MEMPercent() float64 {
	switch m.tick {
	case 0:
		return 72.8
	case 1:
		return 68.1
	default:
		return 75.4
	}
}
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

const mockMemTotalBytes = 17179869184 // 16GB

// CPUCores returns a fixed core count for deterministic tests.
func (m *MockProvider) CPUCores() int {
	return 10
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

// MEMStats returns memory bytes aligned with MEMPercent on a 16GB mock machine.
func (m *MockProvider) MEMStats() MemStats {
	pct := m.MEMPercent()
	used := uint64(float64(mockMemTotalBytes) * pct / 100.0)
	return MemStats{TotalBytes: mockMemTotalBytes, UsedBytes: used}
}

// SwapStats returns swap totals for the current tick.
func (m *MockProvider) SwapStats() SwapStats {
	switch m.tick {
	case 0:
		return SwapStats{TotalBytes: 2147483648, UsedBytes: 104857600}
	case 1:
		return SwapStats{TotalBytes: 2147483648, UsedBytes: 157286400}
	default:
		return SwapStats{TotalBytes: 4294967296, UsedBytes: 209715200}
	}
}

// DiskStats returns root volume disk totals for the current tick.
func (m *MockProvider) DiskStats() DiskStats {
	switch m.tick {
	case 0:
		return DiskStats{TotalBytes: 536870912000, UsedBytes: 214748364800}
	case 1:
		return DiskStats{TotalBytes: 536870912000, UsedBytes: 241591910400}
	default:
		return DiskStats{TotalBytes: 1099511627776, UsedBytes: 429496729600}
	}
}
package monitor

import (
	"github.com/shirou/gopsutil/v4/cpu"
	"github.com/shirou/gopsutil/v4/mem"
)

// RealProvider reads live CPU and memory metrics from the OS.
type RealProvider struct{}

// NewRealProvider creates a provider backed by gopsutil.
func NewRealProvider() *RealProvider {
	return &RealProvider{}
}

// CPUPercent returns aggregate CPU utilization across all processors.
func (r *RealProvider) CPUPercent() float64 {
	percents, err := cpu.Percent(0, false)
	if err != nil || len(percents) == 0 {
		return 0
	}
	return percents[0]
}

// MEMPercent returns memory utilization as (active + wired) / physical * 100.
func (r *RealProvider) MEMPercent() float64 {
	vm, err := mem.VirtualMemory()
	if err != nil || vm.Total == 0 {
		return 0
	}
	used := vm.Active + vm.Wired
	return float64(used) / float64(vm.Total) * 100.0
}
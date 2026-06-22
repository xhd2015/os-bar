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

// CPUCores returns the number of logical CPUs.
func (r *RealProvider) CPUCores() int {
	n, err := cpu.Counts(true)
	if err != nil {
		return 0
	}
	return n
}

// MEMPercent returns memory pressure as (total - available) / physical * 100.
// Matches gopsutil UsedPercent: accounts for active, wired, compressed, etc.
// Inactive/cache remain in Available — RAM the kernel can reclaim for new apps.
func (r *RealProvider) MEMPercent() float64 {
	vm, err := mem.VirtualMemory()
	if err != nil {
		return 0
	}
	return vm.UsedPercent
}

// MEMStats returns physical memory total and used bytes.
// Used = total - available (not free for new workloads without reclaiming pages).
func (r *RealProvider) MEMStats() MemStats {
	vm, err := mem.VirtualMemory()
	if err != nil {
		return MemStats{}
	}
	used := vm.Used
	if used == 0 && vm.Total > vm.Available {
		used = vm.Total - vm.Available
	}
	return MemStats{
		TotalBytes: vm.Total,
		UsedBytes:  used,
	}
}

// SwapStats returns total and used swap space from the OS.
// On darwin, VirtualMemory does not include swap; use SwapMemory (sysctl vm.swapusage).
func (r *RealProvider) SwapStats() SwapStats {
	swap, err := mem.SwapMemory()
	if err != nil {
		return SwapStats{}
	}
	return SwapStats{TotalBytes: swap.Total, UsedBytes: swap.Used}
}
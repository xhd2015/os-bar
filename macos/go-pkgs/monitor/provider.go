package monitor

// MemStats holds total and used physical memory in bytes.
type MemStats struct {
	TotalBytes uint64
	UsedBytes  uint64
}

// SwapStats holds total and used swap space in bytes.
type SwapStats struct {
	TotalBytes uint64
	UsedBytes  uint64
}

// DiskStats holds total and used disk space on the root volume in bytes.
type DiskStats struct {
	TotalBytes uint64
	UsedBytes  uint64
}

// MetricsProvider supplies point-in-time CPU, memory, swap, and disk metrics.
type MetricsProvider interface {
	CPUPercent() float64
	CPUCores() int
	MEMPercent() float64
	MEMStats() MemStats
	SwapStats() SwapStats
	DiskStats() DiskStats
}
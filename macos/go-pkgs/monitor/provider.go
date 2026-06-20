package monitor

// MetricsProvider supplies point-in-time CPU and memory utilization percentages.
type MetricsProvider interface {
	CPUPercent() float64
	MEMPercent() float64
}
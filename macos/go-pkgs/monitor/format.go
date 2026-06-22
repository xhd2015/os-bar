package monitor

import "fmt"

const (
	gib = 1024 * 1024 * 1024
	mib = 1024 * 1024
)

// FormatBytes formats a byte count as a binary integer unit label (GB, MB, or B).
func FormatBytes(bytes uint64) string {
	if bytes == 0 {
		return "0B"
	}
	if bytes >= gib {
		return fmt.Sprintf("%dGB", bytes/gib)
	}
	if bytes >= mib {
		return fmt.Sprintf("%dMB", bytes/mib)
	}
	return fmt.Sprintf("%dB", bytes)
}

// FormatMemDisplay formats memory as "37% (5GB/16GB)" — rounded percent, then used/total.
func FormatMemDisplay(total, used uint64) string {
	if total == 0 {
		return "0% (0B/0B)"
	}
	percent := (used*100 + total/2) / total
	return fmt.Sprintf("%d%% (%s/%s)", percent, FormatBytes(used), FormatBytes(total))
}

// FormatCPUDisplay formats CPU as "33.1% (10 cores)".
func FormatCPUDisplay(percent float64, cores int) string {
	if cores <= 0 {
		return fmt.Sprintf("%.1f%%", percent)
	}
	return fmt.Sprintf("%.1f%% (%d cores)", percent, cores)
}

// FormatSwapDisplay formats swap as "89% (8GB/9GB)" — rounded percent, then used/total.
func FormatSwapDisplay(total, used uint64) string {
	if total == 0 {
		return "0% (0B/0B)"
	}
	percent := (used*100 + total/2) / total
	return fmt.Sprintf("%d%% (%s/%s)", percent, FormatBytes(used), FormatBytes(total))
}
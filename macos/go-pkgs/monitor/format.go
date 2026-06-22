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

const (
	gbDecimal = 1_000_000_000
	mbDecimal = 1_000_000
)

// FormatDiskBytesDecimal formats disk bytes as decimal (1000-based) GB/MB labels.
func FormatDiskBytesDecimal(bytes uint64) string {
	if bytes == 0 {
		return "0B"
	}
	if bytes >= gbDecimal {
		return fmt.Sprintf("%.2fGB", float64(bytes)/float64(gbDecimal))
	}
	if bytes >= mbDecimal {
		return fmt.Sprintf("%.2fMB", float64(bytes)/float64(mbDecimal))
	}
	return fmt.Sprintf("%dB", bytes)
}

// FormatDiskBytes is an alias for FormatDiskBytesDecimal.
func FormatDiskBytes(bytes uint64) string {
	return FormatDiskBytesDecimal(bytes)
}

// FormatDiskBytesBinaryUsed formats used disk bytes as 1024-based GB with two decimals.
func FormatDiskBytesBinaryUsed(bytes uint64) string {
	if bytes == 0 {
		return "0B"
	}
	if bytes >= gib {
		return fmt.Sprintf("%.2fGB", float64(bytes)/float64(gib))
	}
	if bytes >= mib {
		return fmt.Sprintf("%.2fMB", float64(bytes)/float64(mib))
	}
	return fmt.Sprintf("%dB", bytes)
}

// FormatDiskBytesBinaryTotal formats total disk bytes as 1024-based integer GB labels.
func FormatDiskBytesBinaryTotal(bytes uint64) string {
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

// FormatDiskDisplay formats disk as
// "99% (450.01GB/460GB, 488.29GB/494.38GB on MacOS Settings)".
func FormatDiskDisplay(total, used uint64) string {
	if total == 0 {
		return "0% (0B/0B)"
	}
	percent := (used*100 + total/2) / total
	return fmt.Sprintf("%d%% (%s/%s, %s/%s on MacOS Settings)",
		percent,
		FormatDiskBytesBinaryUsed(used), FormatDiskBytesBinaryTotal(total),
		FormatDiskBytesDecimal(used), FormatDiskBytesDecimal(total))
}
package server

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/xhd2015/os-bar/macos/go-pkgs/monitor"
)

type daemon struct {
	port     int
	mockMode bool
	provider monitor.MetricsProvider
	mock     *monitor.MockProvider
}

func (d *daemon) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (d *daemon) handleMetrics(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, d.metricsPayload())
}

func (d *daemon) handleInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"port": d.port,
		"mock": d.mockMode,
	})
}

func (d *daemon) handleAdvanceTick(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSONError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if !d.mockMode || d.mock == nil {
		writeJSONError(w, http.StatusForbidden, "mock mode required")
		return
	}
	d.mock.AdvanceTick()
	writeJSON(w, http.StatusOK, d.metricsPayload())
}

func (d *daemon) handleNotFound(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.URL.Path, "/api/") {
		writeJSONError(w, http.StatusNotFound, "not found")
		return
	}
	http.NotFound(w, r)
}

type metricsPayload struct {
	CPUPercent     float64 `json:"cpu_percent"`
	CPUCores       int     `json:"cpu_cores"`
	MEMPercent     float64 `json:"mem_percent"`
	MemTotalBytes  uint64  `json:"mem_total_bytes"`
	MemUsedBytes   uint64  `json:"mem_used_bytes"`
	SwapTotalBytes uint64  `json:"swap_total_bytes"`
	SwapUsedBytes  uint64  `json:"swap_used_bytes"`
	DiskTotalBytes uint64  `json:"disk_total_bytes"`
	DiskUsedBytes  uint64  `json:"disk_used_bytes"`
}

func (d *daemon) metricsPayload() metricsPayload {
	mem := d.provider.MEMStats()
	swap := d.provider.SwapStats()
	disk := d.provider.DiskStats()
	return metricsPayload{
		CPUPercent:     d.provider.CPUPercent(),
		CPUCores:       d.provider.CPUCores(),
		MEMPercent:     d.provider.MEMPercent(),
		MemTotalBytes:  mem.TotalBytes,
		MemUsedBytes:   mem.UsedBytes,
		SwapTotalBytes: swap.TotalBytes,
		SwapUsedBytes:  swap.UsedBytes,
		DiskTotalBytes: disk.TotalBytes,
		DiskUsedBytes:  disk.UsedBytes,
	}
}

func writeJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeJSONError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
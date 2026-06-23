# Server Package — Doc-Style Test Tree

Test suite for the `go-pkgs/server` library exercised via the thin
`os-bar-daemon serve` CLI. Validates process lifecycle (health, singleton)
and metrics HTTP API parity with the former Swift `SystemMonitor` /
`TestHelper` mock provider.

All tests run against an isolated state directory, ephemeral port, and
`--mock-metrics` — never production port `38270` or real `~/.os-bar/`.

## Version

0.0.1

# DSN (Domain Specific Notion)

The **server package** (`go-pkgs/server`) implements the daemon HTTP server
and metrics handlers. The thin **CLI** (`cmd/os-bar`, binary `os-bar-daemon`)
delegates `serve` to `server.RunServe`. The **daemon** is a long-lived
`os-bar-daemon serve` process bound to `127.0.0.1` on an ephemeral test
port (default production port `38270`).

A **metrics provider** (`go-pkgs/monitor`) supplies point-in-time CPU and MEM
percentages plus **swap stats** (`SwapTotal`, `SwapUsed` bytes from
`mem.VirtualMemory()` on macOS) and **disk stats** (`DiskTotal`, `DiskUsed`
bytes from `disk.Usage("/")` on the root volume). In **mock mode**
(`--mock-metrics`), the provider returns deterministic tick-table values and
exposes `POST /api/test/advance-tick` to advance to the next snapshot (parity
with Swift `MockSystemInfoProvider`).

**CLI clients** (`os-bar metrics`) and **test harness HTTP clients** talk
to the daemon over JSON REST. A **metrics snapshot** is
`{cpu_percent, mem_percent, swap_total_bytes, swap_used_bytes, disk_total_bytes, disk_used_bytes}` — CPU/MEM are `float64` in `[0.0, 100.0]`; swap and
disk fields are `uint64` with `0 <= used_bytes <= total_bytes`.

A **format helper** (`monitor.FormatBytes`, `monitor.FormatSwapDisplay`,
`monitor.FormatDiskBytesBinaryUsed`, `FormatDiskBytesBinaryTotal`,
`FormatDiskBytesDecimal`, `FormatDiskDisplay`) converts raw byte counts for
dropdown display. Disk shows both 1024-based (`454.35GB/460GB`) and decimal
(`488.06GB/494.38GB on MacOS Settings`) sizes. Formatting is client-side in
production but tested via the shared Go helpers from the same harness.

On disk under the state dir (`$HOME/.os-bar/os-bar/`, overridable via
`--state-dir` or `OS_BAR_STATE_DIR`): `daemon.pid` only. No metrics history.

Mock tick table:

| Tick | CPU % | MEM % | swap_total_bytes | swap_used_bytes | disk_total_bytes | disk_used_bytes |
|------|-------|-------|------------------|-----------------|------------------|-----------------|
| 0 | 45.2 | 72.8 | 2147483648 (2 GB) | 104857600 (100 MB) | 536870912000 (500 GiB) | 214748364800 (200 GiB) |
| 1 | 52.3 | 68.1 | 2147483648 (2 GB) | 157286400 (150 MB) | 536870912000 (500 GiB) | 241591910400 (225 GiB) |
| 2+ | 38.7 | 75.4 | 4294967296 (4 GB) | 209715200 (200 MB) | 1099511627776 (1 TiB) | 429496729600 (400 GiB) |

## Decision Tree

```
server/tests/                                 ROOT: Request{Action, Port, StateDir, MockMetrics, ...}
│                                                      Response{BaseURL, HTTPStatus, CPUPercent, ...}
│                                                      Run() builds os-bar-daemon, starts serve, HTTP client
│
├── lifecycle/                                DECISION: concern = process lifecycle
│   └── [SETUP] ephemeral port, isolated state dir
│   │
│   ├── health/                               LEAF: GET /api/health → 200 ok
│   │   ├── SETUP → mock daemon, GET /api/health
│   │   └── ASSERT → status 200, body {"ok":true}
│   │
│   └── singleton/                            LEAF: second serve exits 0, one listener
│       ├── SETUP → Action=daemon_singleton
│       └── ASSERT → SecondStartExitCode=0, health OK, isolated PID file
│
└── metrics-api/                              DECISION: concern = metrics HTTP API (replaces menubar-monitor)
    └── [SETUP] MockMetrics=true, Action=metrics_fetch or metrics_tick
    │
    ├── cpu-in-range/                         LEAF: GET /api/metrics → cpu ∈ [0,100]
    ├── mem-in-range/                         LEAF: GET /api/metrics → mem ∈ [0,100]
    ├── both-valid/                           LEAF: both metrics present and in range
    ├── refresh-on-tick/                      LEAF: tick advances mock CPU/MEM (45.2→52.3)
    │
    ├── swap-api/                             DECISION: concern = swap HTTP API fields
    │   ├── swap-bytes-present/               LEAF: tick 0 swap fields present
    │   ├── swap-bytes-valid/                 LEAF: 0 <= used <= total
    │   └── swap-refresh-on-tick/             LEAF: tick 0→1 swap used changes, total stable
    │
    ├── swap-format/                          DECISION: concern = swap display formatting
    │   ├── swap-format-total/                LEAF: FormatBytes(2 GiB) → "2GB"
    │   ├── swap-format-used/                 LEAF: FormatBytes(100 MiB) → "100MB"
    │   ├── swap-format-zero/                 LEAF: FormatBytes(0) → "0B"
    │   └── swap-format-display/              LEAF: FormatSwapDisplay → "5% (100MB/2GB)"
    │
    ├── disk-api/                             DECISION: concern = disk HTTP API fields
    │   ├── disk-bytes-present/               LEAF: tick 0 disk fields present
    │   ├── disk-bytes-valid/                 LEAF: 0 <= used <= total
    │   └── disk-refresh-on-tick/             LEAF: tick 0→1 disk used changes, total stable
    │
    └── disk-format/                          DECISION: concern = disk display formatting
        ├── disk-format-total/                LEAF: FormatDiskBytesBinaryTotal(500 GiB) → "500GB"
        ├── disk-format-used/                 LEAF: FormatDiskBytesBinaryUsed(200 GiB) → "200.00GB"
        ├── disk-format-zero/                 LEAF: FormatDiskBytesDecimal(0) → "0B"
        └── disk-format-display/              LEAF: FormatDiskDisplay → dual 1024 + decimal line
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Concern group | lifecycle, metrics-api |
| 2 | Resource concern | swap-api, swap-format, disk-api, disk-format |
| 3 | Action | metrics_fetch, metrics_tick, format_bytes, format_swap_display, format_disk_display, ... |
| 4 | MockMetrics | true (API leaves), N/A (format leaves) |
| 5 | Tick state | 0 (present/valid/format), 0→1 (refresh) |
| 6 | Format input | total bytes, used bytes, zero, display pair |
| 7 | Port / StateDir | ephemeral port 0, isolated t.TempDir() state |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `lifecycle/health/` | `GET /api/health` returns 200 with `{"ok":true}` |
| 2 | `lifecycle/singleton/` | Second `serve` exits 0; one healthy listener remains |
| 3 | `metrics-api/cpu-in-range/` | `GET /api/metrics` → `cpu_percent ∈ [0.0, 100.0]` (mock tick 0: 45.2) |
| 4 | `metrics-api/mem-in-range/` | `GET /api/metrics` → `mem_percent ∈ [0.0, 100.0]` (mock tick 0: 72.8) |
| 5 | `metrics-api/both-valid/` | Both CPU and MEM in range and non-zero in mock mode |
| 6 | `metrics-api/refresh-on-tick/` | `POST /api/test/advance-tick` changes CPU/MEM (45.2→52.3 CPU) |
| 7 | `metrics-api/swap-api/swap-bytes-present/` | `GET /api/metrics` includes swap fields at mock tick 0 |
| 8 | `metrics-api/swap-api/swap-bytes-valid/` | `0 <= swap_used_bytes <= swap_total_bytes` |
| 9 | `metrics-api/swap-api/swap-refresh-on-tick/` | advance-tick: used 104857600→157286400, total stays 2147483648 |
| 10 | `metrics-api/swap-format/swap-format-total/` | `FormatBytes(2147483648)` → `"2GB"` |
| 11 | `metrics-api/swap-format/swap-format-used/` | `FormatBytes(104857600)` → `"100MB"` |
| 12 | `metrics-api/swap-format/swap-format-zero/` | `FormatBytes(0)` → `"0B"` |
| 13 | `metrics-api/swap-format/swap-format-display/` | `FormatSwapDisplay(2147483648, 104857600)` → `"5% (100MB/2GB)"` |
| 14 | `metrics-api/disk-api/disk-bytes-present/` | `GET /api/metrics` includes disk fields at mock tick 0 |
| 15 | `metrics-api/disk-api/disk-bytes-valid/` | `0 <= disk_used_bytes <= disk_total_bytes` |
| 16 | `metrics-api/disk-api/disk-refresh-on-tick/` | advance-tick: used 214748364800→241591910400, total stays 536870912000 |
| 17 | `metrics-api/disk-format/disk-format-total/` | `FormatDiskBytesBinaryTotal(536870912000)` → `"500GB"` |
| 18 | `metrics-api/disk-format/disk-format-used/` | `FormatDiskBytesBinaryUsed(214748364800)` → `"200.00GB"` |
| 19 | `metrics-api/disk-format/disk-format-zero/` | `FormatDiskBytesDecimal(0)` → `"0B"` |
| 20 | `metrics-api/disk-format/disk-format-display/` | `FormatDiskDisplay(...)` → `"40% (200.00GB/500GB, 214.75GB/536.87GB on MacOS Settings)"` |

## How to Run

```sh
cd macos/go-pkgs/cmd/os-bar

# Validate tree structure
doctest vet ../../server/tests

# Run all server tests (RED until implementation lands)
doctest test ../../server/tests

# Run a single leaf
doctest test ../../server/tests/lifecycle/health

# Verbose
doctest test -v ../../server/tests/...
```

```go
import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/xhd2015/os-bar/macos/go-pkgs/monitor"
)

const (
	actionStartDaemon     = "start_daemon"
	actionStopDaemon      = "stop_daemon"
	actionHTTPRequest     = "http_request"
	actionHTTPSequence    = "http_sequence"
	actionDaemonSingleton = "daemon_singleton"
	actionMetricsFetch       = "metrics_fetch"
	actionMetricsTick        = "metrics_tick"
	actionFormatBytes        = "format_bytes"
	actionFormatSwapDisplay  = "format_swap_display"
	actionFormatDiskBytes           = "format_disk_bytes"
	actionFormatDiskBytesBinaryUsed = "format_disk_bytes_binary_used"
	actionFormatDiskBytesBinaryTotal = "format_disk_bytes_binary_total"
	actionFormatDiskDisplay         = "format_disk_display"

	daemonReadyTimeout = 10 * time.Second
	daemonReadyPoll    = 50 * time.Millisecond
)

// HTTPStep is one request in a multi-step flow.
type HTTPStep struct {
	Method      string `json:"method,omitempty"`
	Path        string `json:"path,omitempty"`
	Body        string `json:"body,omitempty"`
	ContentType string `json:"content_type,omitempty"`
}

// MetricsTickResult captures before/after snapshots for refresh-on-tick leaves.
type MetricsTickResult struct {
	BeforeCPU       float64 `json:"before_cpu"`
	BeforeMEM       float64 `json:"before_mem"`
	BeforeSwapTotal uint64  `json:"before_swap_total"`
	BeforeSwapUsed  uint64  `json:"before_swap_used"`
	BeforeDiskTotal uint64  `json:"before_disk_total"`
	BeforeDiskUsed  uint64  `json:"before_disk_used"`
	AfterCPU        float64 `json:"after_cpu"`
	AfterMEM        float64 `json:"after_mem"`
	AfterSwapTotal  uint64  `json:"after_swap_total"`
	AfterSwapUsed   uint64  `json:"after_swap_used"`
	AfterDiskTotal  uint64  `json:"after_disk_total"`
	AfterDiskUsed   uint64  `json:"after_disk_used"`
}

// Request drives daemon lifecycle and HTTP calls. Defined only at root.
type Request struct {
	Action      string
	Port        int // 0 = assign ephemeral
	StateDir    string
	MockMetrics bool
	HTTPMethod  string
	HTTPPath    string
	HTTPBody    string
	ContentType string
	HTTPSteps        []HTTPStep
	FormatBytesInput uint64
	FormatSwapTotal  uint64
	FormatSwapUsed   uint64
	FormatDiskTotal  uint64
	FormatDiskUsed   uint64
}

// Response captures daemon and HTTP outcomes.
type Response struct {
	BaseURL             string
	HTTPStatus          int
	HTTPBody            string
	CPUPercent          float64
	MEMPercent          float64
	SwapTotalBytes      uint64
	SwapUsedBytes       uint64
	DiskTotalBytes      uint64
	DiskUsedBytes       uint64
	FormatResult        string
	PID                 int
	SecondStartExitCode int
	StateDir            string
	Error               string
}

type daemonHandle struct {
	cmd        *exec.Cmd
	port       int
	baseURL    string
	binary     string
	stateDir   string
	mockMetrics bool
}

var activeDaemon *daemonHandle

func buildDaemonBinary(t *testing.T) string {
	t.Helper()
	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..", "cmd", "os-bar")
	binaryPath := filepath.Join(t.TempDir(), "os-bar-daemon")
	buildCmd := exec.Command("go", "build", "-o", binaryPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		t.Fatalf("go build os-bar-daemon: %v\n%s", err, out)
	}
	return binaryPath
}

func resolveStateDir(t *testing.T, req *Request) string {
	t.Helper()
	if req.StateDir != "" {
		if err := os.MkdirAll(req.StateDir, 0755); err != nil {
			t.Fatalf("mkdir stateDir: %v", err)
		}
		return req.StateDir
	}
	stateDir := filepath.Join(t.TempDir(), "state")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		t.Fatalf("mkdir stateDir: %v", err)
	}
	req.StateDir = stateDir
	return stateDir
}

func pickEphemeralPort(t *testing.T) int {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen ephemeral port: %v", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()
	return port
}

func waitForDaemonReady(t *testing.T, baseURL string) bool {
	t.Helper()
	deadline := time.Now().Add(daemonReadyTimeout)
	client := &http.Client{Timeout: 500 * time.Millisecond}
	for time.Now().Before(deadline) {
		resp, err := client.Get(baseURL + "/api/health")
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == 200 {
				return true
			}
		}
		time.Sleep(daemonReadyPoll)
	}
	return false
}

func stopDaemonProcess(handle *daemonHandle) {
	if handle == nil || handle.cmd == nil || handle.cmd.Process == nil {
		return
	}
	_ = handle.cmd.Process.Signal(syscall.SIGTERM)
	done := make(chan struct{})
	go func() {
		_ = handle.cmd.Wait()
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		_ = handle.cmd.Process.Kill()
		_ = handle.cmd.Wait()
	}
}

func startDaemonProcess(t *testing.T, binary, stateDir string, port int, mockMetrics bool) *daemonHandle {
	t.Helper()
	if port == 0 {
		port = pickEphemeralPort(t)
	}

	args := []string{
		"serve",
		"--port", strconv.Itoa(port),
		"--state-dir", stateDir,
	}
	if mockMetrics {
		args = append(args, "--mock-metrics")
	}
	cmd := exec.Command(binary, args...)
	cmd.Env = append(os.Environ(), "OS_BAR_STATE_DIR="+stateDir)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr

	if err := cmd.Start(); err != nil {
		t.Fatalf("start daemon: %v", err)
	}

	baseURL := fmt.Sprintf("http://127.0.0.1:%d", port)
	if !waitForDaemonReady(t, baseURL) {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		t.Fatalf("daemon not ready on %s\nstderr: %s", baseURL, stderr.String())
	}

	handle := &daemonHandle{
		cmd:         cmd,
		port:        port,
		baseURL:     baseURL,
		binary:      binary,
		stateDir:    stateDir,
		mockMetrics: mockMetrics,
	}
	t.Cleanup(func() {
		stopDaemonProcess(handle)
	})
	return handle
}

func ensureDaemon(t *testing.T, binary string, req *Request) *daemonHandle {
	t.Helper()
	if activeDaemon != nil {
		return activeDaemon
	}
	stateDir := resolveStateDir(t, req)
	mockMetrics := req.MockMetrics
	if !mockMetrics && req.Action != actionDaemonSingleton {
		mockMetrics = true
	}
	activeDaemon = startDaemonProcess(t, binary, stateDir, req.Port, mockMetrics)
	return activeDaemon
}

func doHTTP(t *testing.T, baseURL string, method, path, body, contentType string) (int, string) {
	t.Helper()
	if method == "" {
		method = http.MethodGet
	}
	var reader io.Reader
	if body != "" {
		reader = strings.NewReader(body)
	}
	httpReq, err := http.NewRequest(method, baseURL+path, reader)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if body != "" {
		if contentType == "" {
			contentType = "application/json"
		}
		httpReq.Header.Set("Content-Type", contentType)
	}
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(httpReq)
	if err != nil {
		t.Fatalf("http %s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(respBody)
}

func parseMetrics(body string) (cpu, mem float64, swapTotal, swapUsed, diskTotal, diskUsed uint64, err error) {
	var payload struct {
		CPUPercent     float64 `json:"cpu_percent"`
		MEMPercent     float64 `json:"mem_percent"`
		SwapTotalBytes uint64  `json:"swap_total_bytes"`
		SwapUsedBytes  uint64  `json:"swap_used_bytes"`
		DiskTotalBytes uint64  `json:"disk_total_bytes"`
		DiskUsedBytes  uint64  `json:"disk_used_bytes"`
	}
	if err = json.Unmarshal([]byte(body), &payload); err != nil {
		return 0, 0, 0, 0, 0, 0, err
	}
	return payload.CPUPercent, payload.MEMPercent, payload.SwapTotalBytes, payload.SwapUsedBytes, payload.DiskTotalBytes, payload.DiskUsedBytes, nil
}

func runSingleton(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	stateDir := resolveStateDir(t, req)
	port := req.Port
	if port == 0 {
		port = pickEphemeralPort(t)
	}

	first := startDaemonProcess(t, binary, stateDir, port, req.MockMetrics)
	pid := first.cmd.Process.Pid

	secondArgs := []string{"serve", "--port", strconv.Itoa(port), "--state-dir", stateDir}
	if req.MockMetrics {
		secondArgs = append(secondArgs, "--mock-metrics")
	}
	second := exec.Command(binary, secondArgs...)
	second.Env = append(os.Environ(), "OS_BAR_STATE_DIR="+stateDir)
	err := second.Run()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		} else {
			t.Fatalf("second serve failed: %v", err)
		}
	}

	status, body := doHTTP(t, first.baseURL, http.MethodGet, "/api/health", "", "")
	activeDaemon = first
	return &Response{
		BaseURL:             first.baseURL,
		HTTPStatus:          status,
		HTTPBody:            body,
		PID:                 pid,
		SecondStartExitCode: exitCode,
		StateDir:            stateDir,
	}
}

func runMetricsFetch(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)
	status, body := doHTTP(t, handle.baseURL, http.MethodGet, "/api/metrics", "", "")
	cpu, mem, swapTotal, swapUsed, diskTotal, diskUsed, parseErr := parseMetrics(body)
	resp := &Response{
		BaseURL:    handle.baseURL,
		HTTPStatus: status,
		HTTPBody:   body,
		StateDir:   handle.stateDir,
	}
	if parseErr == nil {
		resp.CPUPercent = cpu
		resp.MEMPercent = mem
		resp.SwapTotalBytes = swapTotal
		resp.SwapUsedBytes = swapUsed
		resp.DiskTotalBytes = diskTotal
		resp.DiskUsedBytes = diskUsed
	} else {
		resp.Error = parseErr.Error()
	}
	return resp
}

func runMetricsTick(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)

	_, body1 := doHTTP(t, handle.baseURL, http.MethodGet, "/api/metrics", "", "")
	beforeCPU, beforeMEM, beforeSwapTotal, beforeSwapUsed, beforeDiskTotal, beforeDiskUsed, err1 := parseMetrics(body1)
	if err1 != nil {
		t.Fatalf("parse before metrics: %v body=%q", err1, body1)
	}

	tickStatus, tickBody := doHTTP(t, handle.baseURL, http.MethodPost, "/api/test/advance-tick", "", "")
	if tickStatus != 200 {
		t.Fatalf("advance-tick: status %d body=%q", tickStatus, tickBody)
	}

	status2, body2 := doHTTP(t, handle.baseURL, http.MethodGet, "/api/metrics", "", "")
	afterCPU, afterMEM, afterSwapTotal, afterSwapUsed, afterDiskTotal, afterDiskUsed, err2 := parseMetrics(body2)
	if err2 != nil {
		t.Fatalf("parse after metrics: %v body=%q", err2, body2)
	}

	tickResult, _ := json.Marshal(MetricsTickResult{
		BeforeCPU:       beforeCPU,
		BeforeMEM:       beforeMEM,
		BeforeSwapTotal: beforeSwapTotal,
		BeforeSwapUsed:  beforeSwapUsed,
		BeforeDiskTotal: beforeDiskTotal,
		BeforeDiskUsed:  beforeDiskUsed,
		AfterCPU:        afterCPU,
		AfterMEM:        afterMEM,
		AfterSwapTotal:  afterSwapTotal,
		AfterSwapUsed:   afterSwapUsed,
		AfterDiskTotal:  afterDiskTotal,
		AfterDiskUsed:   afterDiskUsed,
	})

	return &Response{
		BaseURL:        handle.baseURL,
		HTTPStatus:     status2,
		HTTPBody:       string(tickResult),
		CPUPercent:     afterCPU,
		MEMPercent:     afterMEM,
		SwapTotalBytes: afterSwapTotal,
		SwapUsedBytes:  afterSwapUsed,
		DiskTotalBytes: afterDiskTotal,
		DiskUsedBytes:  afterDiskUsed,
		StateDir:       handle.stateDir,
		Error:          "",
	}
}

func runHTTPSequence(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)
	resp := &Response{
		BaseURL:  handle.baseURL,
		StateDir: handle.stateDir,
	}
	for _, step := range req.HTTPSteps {
		status, body := doHTTP(t, handle.baseURL, step.Method, step.Path, step.Body, step.ContentType)
		resp.HTTPStatus = status
		resp.HTTPBody = body
		if step.Path == "/api/metrics" {
			cpu, mem, swapTotal, swapUsed, diskTotal, diskUsed, err := parseMetrics(body)
			if err == nil {
				resp.CPUPercent = cpu
				resp.MEMPercent = mem
				resp.SwapTotalBytes = swapTotal
				resp.SwapUsedBytes = swapUsed
				resp.DiskTotalBytes = diskTotal
				resp.DiskUsedBytes = diskUsed
			}
		}
	}
	return resp
}

func runHTTPRequest(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)
	status, body := doHTTP(t, handle.baseURL, req.HTTPMethod, req.HTTPPath, req.HTTPBody, req.ContentType)
	resp := &Response{
		BaseURL:    handle.baseURL,
		HTTPStatus: status,
		HTTPBody:   body,
		StateDir:   handle.stateDir,
	}
	if req.HTTPPath == "/api/metrics" {
		cpu, mem, swapTotal, swapUsed, diskTotal, diskUsed, err := parseMetrics(body)
		if err == nil {
			resp.CPUPercent = cpu
			resp.MEMPercent = mem
			resp.SwapTotalBytes = swapTotal
			resp.SwapUsedBytes = swapUsed
			resp.DiskTotalBytes = diskTotal
			resp.DiskUsedBytes = diskUsed
		}
	}
	return resp
}

func runFormatBytes(t *testing.T, req *Request) *Response {
	t.Helper()
	return &Response{
		FormatResult: monitor.FormatBytes(req.FormatBytesInput),
	}
}

func runFormatSwapDisplay(t *testing.T, req *Request) *Response {
	t.Helper()
	return &Response{
		FormatResult: monitor.FormatSwapDisplay(req.FormatSwapTotal, req.FormatSwapUsed),
	}
}

func runFormatDiskBytes(t *testing.T, req *Request) *Response {
	t.Helper()
	return &Response{
		FormatResult: monitor.FormatDiskBytesDecimal(req.FormatBytesInput),
	}
}

func runFormatDiskBytesBinaryUsed(t *testing.T, req *Request) *Response {
	t.Helper()
	return &Response{
		FormatResult: monitor.FormatDiskBytesBinaryUsed(req.FormatBytesInput),
	}
}

func runFormatDiskBytesBinaryTotal(t *testing.T, req *Request) *Response {
	t.Helper()
	return &Response{
		FormatResult: monitor.FormatDiskBytesBinaryTotal(req.FormatBytesInput),
	}
}

func runFormatDiskDisplay(t *testing.T, req *Request) *Response {
	t.Helper()
	return &Response{
		FormatResult: monitor.FormatDiskDisplay(req.FormatDiskTotal, req.FormatDiskUsed),
	}
}

func Run(t *testing.T, req *Request) (*Response, error) {
	activeDaemon = nil
	binary := buildDaemonBinary(t)

	switch req.Action {
	case actionStartDaemon:
		stateDir := resolveStateDir(t, req)
		handle := startDaemonProcess(t, binary, stateDir, req.Port, req.MockMetrics)
		activeDaemon = handle
		return &Response{
			BaseURL:  handle.baseURL,
			StateDir: stateDir,
			PID:      handle.cmd.Process.Pid,
		}, nil
	case actionStopDaemon:
		if activeDaemon != nil {
			stopDaemonProcess(activeDaemon)
			activeDaemon = nil
		}
		return &Response{}, nil
	case actionDaemonSingleton:
		return runSingleton(t, binary, req), nil
	case actionMetricsFetch:
		return runMetricsFetch(t, binary, req), nil
	case actionMetricsTick:
		return runMetricsTick(t, binary, req), nil
	case actionFormatBytes:
		return runFormatBytes(t, req), nil
	case actionFormatSwapDisplay:
		return runFormatSwapDisplay(t, req), nil
	case actionFormatDiskBytes:
		return runFormatDiskBytes(t, req), nil
	case actionFormatDiskBytesBinaryUsed:
		return runFormatDiskBytesBinaryUsed(t, req), nil
	case actionFormatDiskBytesBinaryTotal:
		return runFormatDiskBytesBinaryTotal(t, req), nil
	case actionFormatDiskDisplay:
		return runFormatDiskDisplay(t, req), nil
	case actionHTTPSequence:
		return runHTTPSequence(t, binary, req), nil
	case actionHTTPRequest, "":
		if len(req.HTTPSteps) > 0 {
			req.Action = actionHTTPSequence
			return runHTTPSequence(t, binary, req), nil
		}
		if req.Action == "" {
			req.Action = actionHTTPRequest
		}
		return runHTTPRequest(t, binary, req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}

func assertStateDirIsolated(t *testing.T, stateDir string) {
	t.Helper()
	realHome, _ := os.UserHomeDir()
	realState := filepath.Join(realHome, ".os-bar", "os-bar")
	absState, _ := filepath.Abs(stateDir)
	absReal, _ := filepath.Abs(realState)
	if absState == absReal || strings.HasPrefix(absState, absReal+string(filepath.Separator)) {
		t.Fatalf("stateDir %q must not be real production path %q", absState, absReal)
	}
}

func parseMetricsTickResult(t *testing.T, body string) MetricsTickResult {
	t.Helper()
	var result MetricsTickResult
	if err := json.Unmarshal([]byte(body), &result); err != nil {
		t.Fatalf("parse metrics tick result: %v body=%q", err, body)
	}
	return result
}
```
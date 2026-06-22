# Scenario

**Feature**: server package owns metrics HTTP daemon; tests drive it via `os-bar-daemon serve` subprocess

```
# test harness builds os-bar-daemon CLI, serve delegates to server package
doctest Run(req) -> build CLI -> serve --state-dir --port --mock-metrics -> server -> daemon

# HTTP client exercises metrics REST API
doctest <- GET /api/metrics (cpu_percent, mem_percent, swap_total_bytes, swap_used_bytes)
doctest -> POST /api/test/advance-tick -> mock provider advances tick
doctest <- GET /api/health | /api/info

# formatter helpers (no daemon)
doctest -> monitor.FormatBytes(bytes) -> "2GB" | "100MB" | "0B"
doctest -> monitor.FormatSwapDisplay(total, used) -> "89%(8GB/9GB)"
```

## Preconditions

- The `os-bar` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "cmd", "os-bar")`.
- Built binary is named `os-bar-daemon` (distinct from Swift `os-bar` app executable).
- The `serve` subcommand binds `127.0.0.1` only and accepts `--port`, `--state-dir`, and `--mock-metrics`.
- **Isolation (mandatory):** Every test uses `stateDir` under `t.TempDir()` and never reads/writes real `~/.os-bar/`.
- Tests use ephemeral ports (`--port 0` or assigned high port); never bind production port `38270`.
- `OS_BAR_STATE_DIR` overrides default state location for the daemon process.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Build `os-bar-daemon` binary to a temp path (once per test).
2. Create `stateDir := filepath.Join(t.TempDir(), "state")` when `req.StateDir` is empty.
3. Register `t.Cleanup` to stop the daemon subprocess.
4. Dispatch by `req.Action`:
   - `start_daemon` — build & start `serve`, store `BaseURL` in response
   - `stop_daemon` — stop background `serve`
   - `http_request` — ensure daemon running, perform one HTTP call
   - `http_sequence` — ensure daemon running, perform `req.HTTPSteps` in order
   - `daemon_singleton` — start twice, assert second exits 0
   - `metrics_fetch` — `GET /api/metrics`, parse into `CPUPercent` / `MEMPercent` / swap bytes
   - `metrics_tick` — `GET /api/metrics`, `POST /api/test/advance-tick`, `GET /api/metrics`; encode before/after CPU/MEM/swap in `HTTPBody`
   - `format_bytes` — call `monitor.FormatBytes(req.FormatBytesInput)`, store in `FormatResult`
   - `format_swap_display` — call `monitor.FormatSwapDisplay(req.FormatSwapTotal, req.FormatSwapUsed)`, store in `FormatResult`
5. Parse `/api/metrics` JSON into `Response.CPUPercent` / `Response.MEMPercent` / swap byte fields.
6. Return `(*Response, nil)`.

## Context

- Metrics response: `{"cpu_percent": float64, "mem_percent": float64, "swap_total_bytes": uint64, "swap_used_bytes": uint64}`; CPU/MEM in `[0.0, 100.0]`.
- Mock tick 0: CPU=45.2, MEM=72.8, swap total=2147483648, swap used=104857600.
- Mock tick 1: CPU=52.3, MEM=68.1, swap total=2147483648, swap used=157286400.
- Mock tick 2+: CPU=38.7, MEM=75.4, swap total=4294967296, swap used=209715200.
- `FormatBytes` / `FormatSwapDisplay`: binary (1024) units, integer labels only (`2GB`, `100MB`, `0B`).
- `POST /api/test/advance-tick` returns 403 when not in mock mode.
- Error parity: unknown path → 404, wrong method on known path → 405.
- Singleton: second `serve` exits 0 if existing PID alive and `/api/health` OK.

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
	AfterCPU        float64 `json:"after_cpu"`
	AfterMEM        float64 `json:"after_mem"`
	AfterSwapTotal  uint64  `json:"after_swap_total"`
	AfterSwapUsed   uint64  `json:"after_swap_used"`
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

func parseMetrics(body string) (cpu, mem float64, swapTotal, swapUsed uint64, err error) {
	var payload struct {
		CPUPercent     float64 `json:"cpu_percent"`
		MEMPercent     float64 `json:"mem_percent"`
		SwapTotalBytes uint64  `json:"swap_total_bytes"`
		SwapUsedBytes  uint64  `json:"swap_used_bytes"`
	}
	if err = json.Unmarshal([]byte(body), &payload); err != nil {
		return 0, 0, 0, 0, err
	}
	return payload.CPUPercent, payload.MEMPercent, payload.SwapTotalBytes, payload.SwapUsedBytes, nil
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
	cpu, mem, swapTotal, swapUsed, parseErr := parseMetrics(body)
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
	} else {
		resp.Error = parseErr.Error()
	}
	return resp
}

func runMetricsTick(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)

	_, body1 := doHTTP(t, handle.baseURL, http.MethodGet, "/api/metrics", "", "")
	beforeCPU, beforeMEM, beforeSwapTotal, beforeSwapUsed, err1 := parseMetrics(body1)
	if err1 != nil {
		t.Fatalf("parse before metrics: %v body=%q", err1, body1)
	}

	tickStatus, tickBody := doHTTP(t, handle.baseURL, http.MethodPost, "/api/test/advance-tick", "", "")
	if tickStatus != 200 {
		t.Fatalf("advance-tick: status %d body=%q", tickStatus, tickBody)
	}

	status2, body2 := doHTTP(t, handle.baseURL, http.MethodGet, "/api/metrics", "", "")
	afterCPU, afterMEM, afterSwapTotal, afterSwapUsed, err2 := parseMetrics(body2)
	if err2 != nil {
		t.Fatalf("parse after metrics: %v body=%q", err2, body2)
	}

	tickResult, _ := json.Marshal(MetricsTickResult{
		BeforeCPU:       beforeCPU,
		BeforeMEM:       beforeMEM,
		BeforeSwapTotal: beforeSwapTotal,
		BeforeSwapUsed:  beforeSwapUsed,
		AfterCPU:        afterCPU,
		AfterMEM:        afterMEM,
		AfterSwapTotal:  afterSwapTotal,
		AfterSwapUsed:   afterSwapUsed,
	})

	return &Response{
		BaseURL:        handle.baseURL,
		HTTPStatus:     status2,
		HTTPBody:       string(tickResult),
		CPUPercent:     afterCPU,
		MEMPercent:     afterMEM,
		SwapTotalBytes: afterSwapTotal,
		SwapUsedBytes:  afterSwapUsed,
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
			cpu, mem, swapTotal, swapUsed, err := parseMetrics(body)
			if err == nil {
				resp.CPUPercent = cpu
				resp.MEMPercent = mem
				resp.SwapTotalBytes = swapTotal
				resp.SwapUsedBytes = swapUsed
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
		cpu, mem, swapTotal, swapUsed, err := parseMetrics(body)
		if err == nil {
			resp.CPUPercent = cpu
			resp.MEMPercent = mem
			resp.SwapTotalBytes = swapTotal
			resp.SwapUsedBytes = swapUsed
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
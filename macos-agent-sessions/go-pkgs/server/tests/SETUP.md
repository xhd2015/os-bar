# Scenario

**Feature**: server package owns HTTP server and session store; tests drive it via thin CLI subprocess

```
# test harness builds agent-sessions CLI, serve delegates to server package
doctest Run(req) -> build CLI -> serve --state-dir --port -> server -> daemon

# HTTP client exercises REST API
doctest -> POST /api/notify -> daemon -> events.json + notify-logs.json
doctest <- GET /api/list (session events)
doctest <- GET /api/health | /api/integrations | /api/logs
```

## Preconditions

- The `agent-sessions` CLI package exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "cmd", "agent-sessions")`.
- The `serve` subcommand binds `127.0.0.1` only and accepts `--port` and `--state-dir`.
- **Isolation (mandatory):** Every test uses `stateDir` under `t.TempDir()` and never reads/writes real `~/.os-bar/`.
- Tests use ephemeral ports (`--port 0` or assigned high port); never bind production port `38271`.
- `AGENT_SESSIONS_STATE_DIR` overrides default state location for the daemon process.
- Integrations tests set `HOME` to a dedicated `fakeHome` temp dir.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Build `agent-sessions` binary to a temp path (once per test).
2. Create `stateDir := filepath.Join(t.TempDir(), "state")` when `req.StateDir` is empty.
3. Create `fakeHome` when integrations tests need isolated `HOME`.
4. If `req.SeedEvents` is set, copy fixture JSON into `stateDir/events.json` before daemon start.
5. Register `t.Cleanup` to stop the daemon subprocess.
6. Dispatch by `req.Action`:
   - `start_daemon` — build & start `serve`, store `BaseURL` in response
   - `stop_daemon` — stop background `serve`
   - `http_request` — ensure daemon running, perform one HTTP call
   - `http_sequence` — ensure daemon running, perform `req.HTTPSteps` in order
   - `daemon_singleton` — start twice, assert second exits 0
   - `integrations_install` — `POST /api/integrations/install` then refresh integrations list
7. Parse JSON bodies into `Response.Events`, `Response.Integrations`, `Response.LogEntries` where applicable.
8. Return `(*Response, nil)`.

## Context

- `SessionEvent` mirrors Swift `SessionEvent`: `{id, dir, timestamp, consumed}`.
- Store rules (parity with `SessionStore.swift`): dedup by dir, cap 20, prune >7 days on load, newest-first sort.
- Notify with `source=="notify"` adds a session event; otherwise log-only.
- Integrations status enum: `missing` | `installed` | `up_to_date` | `outdated`.
- Error parity: invalid JSON → 400, missing dir → 400, unknown path → 404, wrong method → 405.

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
)

const (
	actionStartDaemon         = "start_daemon"
	actionStopDaemon          = "stop_daemon"
	actionHTTPRequest         = "http_request"
	actionHTTPSequence        = "http_sequence"
	actionDaemonSingleton     = "daemon_singleton"
	actionIntegrationsInstall = "integrations_install"

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

// SessionEvent mirrors the Swift SessionEvent / Go daemon model.
type SessionEvent struct {
	ID        string `json:"id"`
	Dir       string `json:"dir"`
	Timestamp string `json:"timestamp"`
	Consumed  bool   `json:"consumed"`
}

// NotifyLogEntry mirrors NotifyLogStore entries.
type NotifyLogEntry struct {
	Source    string `json:"source"`
	Timestamp string `json:"timestamp"`
	Dir       string `json:"dir"`
	Event     string `json:"event,omitempty"`
}

// Integration mirrors integrations --json entries.
type Integration struct {
	ID     string `json:"id"`
	Status string `json:"status"`
	Path   string `json:"path"`
	Scope  string `json:"scope"`
}

// Request drives daemon lifecycle and HTTP calls. Defined only at root.
type Request struct {
	Action       string
	Port         int // 0 = assign ephemeral
	StateDir     string
	HomeDir      string
	HTTPMethod   string
	HTTPPath     string
	HTTPBody     string
	ContentType  string
	HTTPSteps    []HTTPStep
	Dir          string
	Target       string // grok|opencode|pi|codex
	Global       bool
	SeedEvents   string // fixture filename under DOCTEST_ROOT/testdata/
}

// Response captures daemon and HTTP outcomes.
type Response struct {
	BaseURL             string
	HTTPStatus          int
	HTTPBody            string
	Events              []SessionEvent
	LogEntries          []NotifyLogEntry
	Integrations        []Integration
	PID                 int
	SecondStartExitCode int
	StateDir            string
	HomeDir             string
	Error               string
}

type daemonHandle struct {
	cmd     *exec.Cmd
	port    int
	baseURL string
	binary  string
	stateDir string
	homeDir  string
}

var activeDaemon *daemonHandle

func buildDaemonBinary(t *testing.T) string {
	t.Helper()
	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..", "cmd", "agent-sessions")
	binaryPath := filepath.Join(t.TempDir(), "agent-sessions")
	buildCmd := exec.Command("go", "build", "-o", binaryPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		t.Fatalf("go build agent-sessions: %v\n%s", err, out)
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

func resolveHomeDir(t *testing.T, req *Request) string {
	t.Helper()
	if req.HomeDir != "" {
		if err := os.MkdirAll(req.HomeDir, 0755); err != nil {
			t.Fatalf("mkdir homeDir: %v", err)
		}
		return req.HomeDir
	}
	homeDir := filepath.Join(t.TempDir(), "home")
	if err := os.MkdirAll(homeDir, 0755); err != nil {
		t.Fatalf("mkdir homeDir: %v", err)
	}
	req.HomeDir = homeDir
	return homeDir
}

func seedEvents(t *testing.T, stateDir, fixtureName string) {
	t.Helper()
	if fixtureName == "" {
		return
	}
	src := filepath.Join(DOCTEST_ROOT, "testdata", fixtureName)
	data, err := os.ReadFile(src)
	if err != nil {
		t.Fatalf("read seed fixture %q: %v", src, err)
	}
	dst := filepath.Join(stateDir, "events.json")
	if err := os.WriteFile(dst, data, 0644); err != nil {
		t.Fatalf("write events.json: %v", err)
	}
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
		// Fallback while /api/health is not implemented yet.
		resp, err = client.Get(baseURL + "/api/list")
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

func startDaemonProcess(t *testing.T, binary, stateDir, homeDir string, port int) *daemonHandle {
	t.Helper()
	if port == 0 {
		port = pickEphemeralPort(t)
	}

	args := []string{
		"serve",
		"--port", strconv.Itoa(port),
		"--state-dir", stateDir,
	}
	cmd := exec.Command(binary, args...)
	cmd.Env = append(os.Environ(),
		"AGENT_SESSIONS_STATE_DIR="+stateDir,
		"HOME="+homeDir,
	)
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
		cmd:      cmd,
		port:     port,
		baseURL:  baseURL,
		binary:   binary,
		stateDir: stateDir,
		homeDir:  homeDir,
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
	homeDir := resolveHomeDir(t, req)
	seedEvents(t, stateDir, req.SeedEvents)
	activeDaemon = startDaemonProcess(t, binary, stateDir, homeDir, req.Port)
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
	req, err := http.NewRequest(method, baseURL+path, reader)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	if body != "" {
		if contentType == "" {
			contentType = "application/json"
		}
		req.Header.Set("Content-Type", contentType)
	}
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("http %s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(respBody)
}

func parseEvents(body string) []SessionEvent {
	var events []SessionEvent
	_ = json.Unmarshal([]byte(body), &events)
	return events
}

func parseLogEntries(body string) []NotifyLogEntry {
	var entries []NotifyLogEntry
	_ = json.Unmarshal([]byte(body), &entries)
	return entries
}

func parseIntegrations(body string) []Integration {
	var payload struct {
		Integrations []Integration `json:"integrations"`
	}
	_ = json.Unmarshal([]byte(body), &payload)
	return payload.Integrations
}

func runSingleton(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	stateDir := resolveStateDir(t, req)
	homeDir := resolveHomeDir(t, req)
	port := req.Port
	if port == 0 {
		port = pickEphemeralPort(t)
	}

	first := startDaemonProcess(t, binary, stateDir, homeDir, port)
	pid := first.cmd.Process.Pid

	second := exec.Command(binary, "serve", "--port", strconv.Itoa(port), "--state-dir", stateDir)
	second.Env = append(os.Environ(),
		"AGENT_SESSIONS_STATE_DIR="+stateDir,
		"HOME="+homeDir,
	)
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
	if status != 200 {
		status, body = doHTTP(t, first.baseURL, http.MethodGet, "/api/list", "", "")
	}

	activeDaemon = first
	return &Response{
		BaseURL:             first.baseURL,
		HTTPStatus:          status,
		HTTPBody:            body,
		PID:                 pid,
		SecondStartExitCode: exitCode,
		StateDir:            stateDir,
		HomeDir:             homeDir,
	}
}

func runIntegrationsInstall(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)
	installBody, _ := json.Marshal(map[string]interface{}{
		"target": req.Target,
		"global": req.Global,
	})
	status, body := doHTTP(t, handle.baseURL, http.MethodPost, "/api/integrations/install", string(installBody), "application/json")

	listStatus, listBody := doHTTP(t, handle.baseURL, http.MethodGet, "/api/integrations?global=1", "", "")
	resp := &Response{
		BaseURL:      handle.baseURL,
		HTTPStatus:   status,
		HTTPBody:     body,
		Integrations: parseIntegrations(listBody),
		StateDir:     handle.stateDir,
		HomeDir:      handle.homeDir,
	}
	if listStatus != 200 && resp.HTTPStatus == 200 {
		resp.HTTPStatus = listStatus
		resp.HTTPBody = listBody
	}
	return resp
}

func runHTTPSequence(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)
	resp := &Response{
		BaseURL:  handle.baseURL,
		StateDir: handle.stateDir,
		HomeDir:  handle.homeDir,
	}
	for _, step := range req.HTTPSteps {
		status, body := doHTTP(t, handle.baseURL, step.Method, step.Path, step.Body, step.ContentType)
		resp.HTTPStatus = status
		resp.HTTPBody = body
		switch {
		case step.Path == "/api/list" || strings.HasPrefix(step.Path, "/api/list?"):
			resp.Events = parseEvents(body)
		case step.Path == "/api/logs" || strings.HasPrefix(step.Path, "/api/logs?"):
			resp.LogEntries = parseLogEntries(body)
		case strings.HasPrefix(step.Path, "/api/integrations"):
			resp.Integrations = parseIntegrations(body)
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
		HomeDir:    handle.homeDir,
	}
	switch {
	case req.HTTPPath == "/api/list" || strings.HasPrefix(req.HTTPPath, "/api/list?"):
		resp.Events = parseEvents(body)
	case req.HTTPPath == "/api/logs" || strings.HasPrefix(req.HTTPPath, "/api/logs?"):
		resp.LogEntries = parseLogEntries(body)
	case strings.HasPrefix(req.HTTPPath, "/api/integrations"):
		resp.Integrations = parseIntegrations(body)
	}
	return resp
}

func Run(t *testing.T, req *Request) (*Response, error) {
	activeDaemon = nil
	binary := buildDaemonBinary(t)

	switch req.Action {
	case actionStartDaemon:
		stateDir := resolveStateDir(t, req)
		homeDir := resolveHomeDir(t, req)
		seedEvents(t, stateDir, req.SeedEvents)
		handle := startDaemonProcess(t, binary, stateDir, homeDir, req.Port)
		activeDaemon = handle
		return &Response{
			BaseURL:  handle.baseURL,
			StateDir: stateDir,
			HomeDir:  homeDir,
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
	case actionIntegrationsInstall:
		return runIntegrationsInstall(t, binary, req), nil
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

func integrationByID(integrations []Integration, id string) *Integration {
	for i := range integrations {
		if integrations[i].ID == id {
			return &integrations[i]
		}
	}
	return nil
}

func assertPathUnderHome(t *testing.T, path, homeDir string) {
	t.Helper()
	absPath, err := filepath.Abs(path)
	if err != nil {
		t.Fatalf("abs %q: %v", path, err)
	}
	homeAbs, err := filepath.Abs(homeDir)
	if err != nil {
		t.Fatalf("abs home %q: %v", homeDir, err)
	}
	if !strings.HasPrefix(absPath, homeAbs+string(filepath.Separator)) && absPath != homeAbs {
		t.Fatalf("path %q is outside homeDir %q", absPath, homeAbs)
	}
}

func assertStateDirIsolated(t *testing.T, stateDir string) {
	t.Helper()
	realHome, _ := os.UserHomeDir()
	realState := filepath.Join(realHome, ".os-bar", "agent-sessions")
	absState, _ := filepath.Abs(stateDir)
	absReal, _ := filepath.Abs(realState)
	if absState == absReal || strings.HasPrefix(absState, absReal+string(filepath.Separator)) {
		t.Fatalf("stateDir %q must not be real production path %q", absState, absReal)
	}
}

func parseTimeISO(ts string) (time.Time, error) {
	t, err := time.Parse(time.RFC3339, ts)
	if err != nil {
		return time.Parse("2006-01-02T15:04:05Z", ts)
	}
	return t, nil
}
```
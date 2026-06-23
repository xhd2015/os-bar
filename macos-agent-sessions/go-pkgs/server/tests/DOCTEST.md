# Server Package — Doc-Style Test Tree

Test suite for the `go-pkgs/server` library exercised via the thin
`agent-sessions serve` CLI. Validates process lifecycle (health, singleton),
HTTP API parity with the former Swift server, session store rules (dedup, cap,
consume, prune-on-load), and integrations REST endpoints.

All tests run against an isolated state directory and ephemeral port — never
production port `38271` or real `~/.os-bar/`.

# DSN (Domain Specific Notion)

The **server package** (`go-pkgs/server`) implements the daemon HTTP server,
session store, and integrations handlers. The thin **CLI** (`cmd/agent-sessions`)
delegates `serve` to `server.RunServe`. The **daemon** is a long-lived
`agent-sessions serve` process bound to `127.0.0.1` on an ephemeral test port.
It owns session events, notify logs, and integration install status under a
configurable **state dir** (`AGENT_SESSIONS_STATE_DIR` or `--state-dir`).

**CLI clients** (`notify`, `list`, `remove`, …) and **test harness HTTP clients**
talk to the daemon over JSON REST. A **session event** is
`{id, dir, timestamp, consumed}` shown in the menu bar. A **notify** POST with
`source=="notify"` pushes into the session store; a **log-only notify** (any
other or absent `source`) appends to `notify-logs.json` only.

The **integrations API** exposes the same status JSON as
`integrations --json --global` and can run installs via HTTP. Tests use an
**isolated home** (`t.TempDir()` fake `HOME`) for integration install paths.

On disk under the state dir: `events.json`, `notify-logs.json`, `daemon.pid`.
`GET /api/info` returns `storage_path` pointing at that directory.


## Version

0.0.2

## Decision Tree

```
server/tests/                                 ROOT: Request{Action, Port, StateDir, ...}
│                                                      Response{BaseURL, HTTPStatus, Events, ...}
│                                                      Run() builds CLI, starts daemon, HTTP client
│
├── lifecycle/                                DECISION: concern = process lifecycle
│   └── [SETUP] daemon must be running or startable
│   │
│   ├── health/                               LEAF: GET /api/health → 200 ok
│   │   ├── SETUP → start daemon, GET /api/health
│   │   └── ASSERT → status 200, body contains "ok":true
│   │
│   └── singleton/                            LEAF: second serve exits 0, one listener
│       ├── SETUP → Action=daemon_singleton
│       └── ASSERT → SecondStartExitCode=0, health OK, same PID file
│
├── sessions-api/                             DECISION: concern = HTTP API parity
│   └── [SETUP] req.Action = http_sequence or http_request
│   │
│   ├── notify-adds-event/                  LEAF: source=notify → list has event
│   ├── notify-log-only/                    LEAF: no source=notify → logs yes, list no
│   ├── list-empty/                         LEAF: fresh daemon → empty list
│   ├── delete-events/                      LEAF: DELETE /api/events?dir=
│   ├── missing-dir/                        LEAF: POST {} → 400
│   ├── wrong-method/                       LEAF: GET /api/notify → 405
│   └── wrong-path/                         LEAF: POST /api/wrong → 404
│
├── store-rules/                              DECISION: concern = session store semantics
│   └── [SETUP] exercises store via HTTP after notify
│   │
│   ├── dedup-bump/                           LEAF: same dir twice → count 1, newer ts
│   ├── dedup-trailing-slash/                 LEAF: dir vs dir/ → count 1, canonical dir
│   ├── cap-20/                               LEAF: 21 dirs → list len 20
│   ├── consume-event/                        LEAF: POST /api/events/consume
│   └── prune-on-load/                        LEAF: seed 8-day-old event, restart, gone
│
└── integrations-api/                         DECISION: concern = integrations REST
    └── [SETUP] fake HOME, global scope
    │
    ├── list-all-missing/                     LEAF: GET /api/integrations?global=1
    └── install-grok/                         LEAF: POST install → up_to_date, files exist
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Concern group | lifecycle, sessions-api, store-rules, integrations-api |
| 2 | Action / HTTP path | health, notify, list, delete, consume, integrations |
| 3 | Request body / query | source=notify vs log-only, dir present vs missing |
| 4 | Store state | empty, seeded, multi-notify, stale events |
| 5 | HOME isolation | default temp vs fakeHome for integrations |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `lifecycle/health/` | `GET /api/health` returns 200 with `{"ok":true}` |
| 2 | `lifecycle/singleton/` | Second `serve` exits 0; one healthy listener remains |
| 3 | `sessions-api/notify-adds-event/` | `POST /api/notify` with `source=notify` adds session event |
| 4 | `sessions-api/notify-log-only/` | Notify without `source=notify` logs only, no menu event |
| 5 | `sessions-api/list-empty/` | Fresh daemon returns empty event list |
| 6 | `sessions-api/delete-events/` | `DELETE /api/events?dir=` removes matching events |
| 7 | `sessions-api/missing-dir/` | `POST /api/notify` without `dir` → 400 |
| 8 | `sessions-api/wrong-method/` | `GET /api/notify` → 405 |
| 9 | `sessions-api/wrong-path/` | `POST /api/wrong` → 404 |
| 10 | `store-rules/dedup-bump/` | Re-notify same dir bumps timestamp, count stays 1 |
| 10b | `store-rules/dedup-trailing-slash/` | Dir with/without trailing slash deduped to one |
| 11 | `store-rules/cap-20/` | 21 distinct dirs capped to 20 events |
| 12 | `store-rules/consume-event/` | `POST /api/events/consume` marks `consumed=true` |
| 13 | `store-rules/prune-on-load/` | 8-day-old seeded event pruned on daemon load |
| 14 | `integrations-api/list-all-missing/` | All four integrations report `missing` (global) |
| 15 | `integrations-api/install-grok/` | Install grok via API; status `up_to_date`, files exist |

## How to Run

```sh
cd macos-agent-sessions/go-pkgs/server

# Validate tree structure
doctest vet ./tests

# Run all server tests (GREEN after server package migration)
doctest test ./tests

# Run a single leaf
doctest test ./tests/lifecycle/health

# Verbose
doctest test -v ./tests/...
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

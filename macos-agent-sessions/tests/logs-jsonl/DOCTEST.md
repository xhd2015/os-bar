# Logs JSONL + Viewer — Doc-Style Test Tree

Test suite for **JSONL log storage** (`notify-logs.jsonl`), legacy migration from
`notify-logs.json`, unchanged `GET /api/logs` JSON-array API, renamed Finder menu
labels, and the new **Logs** viewer window (format + 2s poll).

Storage leaves use the Go daemon harness (`buildDaemonBinary`, `startDaemonProcess`,
HTTP sequences). Menu and viewer leaves use the Swift `TestHelper` (RED until
`OpenLogsMenuState`, `LogsViewerViewModel`, and new helper actions exist).

## Version

0.0.2

# DSN (Domain Specific Notion)

The **daemon store** (`go-pkgs/server/store.go`) persists notify logs as **JSONL**
at `{stateDir}/notify-logs.jsonl` — one `NotifyLogEntry` JSON object per line,
append-only writes, cap 200 with oldest evicted. On first load, legacy
`notify-logs.json` (JSON array) is **migrated** to `.jsonl` and the `.json` file
is **removed**.

`GET /api/logs` still returns a JSON **array** (server decodes JSONL in memory).

The **menu bar app** renames **Open Logs** → **Show Logs in Finder** (disabled with
`(daemon unreachable)` suffix on error). A new **Logs** menu item opens a dedicated
window that polls `GET /api/logs` every **2s**; it stays **enabled** even when the
daemon is down (error banner in window).

**TestHelper** mirrors pure Swift logic for menu labels and viewer formatting/poll
detection without UI automation.

## Decision Tree

```
logs-jsonl/                              ROOT: Request{Action, Port, StateDir, ...}
│                                                 Response{LogEntries, MenuLabel, DisplayLine, ...}
│                                                 Run() → daemon HTTP or Swift test helper
│
├── append/                                DECISION: concern = JSONL append on disk
│   └── [SETUP] req.Action = http_sequence; assert notify-logs.jsonl
│   │
│   ├── writes-jsonl-line/                 LEAF: 1 notify → 1 line, valid JSON, trailing \n
│   ├── second-append/                     LEAF: 2 notifies → 2 lines, no `[` array wrapper
│   └── notification-click-logs-method/    LEAF: command log persists openMethod + kool fields
│
├── load/                                  DECISION: concern = JSONL load on daemon start
│   └── [SETUP] seed notify-logs.jsonl before serve
│   │
│   └── reads-jsonl/                       LEAF: 3-line seed → GET /api/logs len 3
│
├── cap/                                   DECISION: concern = 200-entry cap on disk
│   └── [SETUP] 201 log-only notifies
│   │
│   └── truncates-at-200/                  LEAF: ≤200 lines, oldest dir evicted
│
├── migrate/                               DECISION: concern = legacy JSON array migration
│   └── [SETUP] seed notify-logs.json (array), start daemon
│   │
│   └── legacy-json-array/                 LEAF: .jsonl created, .json removed, entries kept
│
├── api/                                   DECISION: concern = HTTP response shape
│   └── [SETUP] notify then GET /api/logs
│   │
│   └── returns-json-array/                LEAF: body is JSON array, not JSONL text
│
├── menu-label/                            DECISION: concern = menu label + enabled (Swift)
│   └── [SETUP] req.Action ∈ {open_logs_menu_state, logs_viewer_menu_state}
│   │
│   ├── finder-ok/                         LEAF: info OK → "Show Logs in Finder", enabled
│   ├── finder-error/                      LEAF: info error → "Show Logs in Finder (daemon unreachable)", disabled
│   └── logs-viewer/                       LEAF: "Logs", enabled=true even with info_error
│
└── viewer/                                DECISION: concern = Logs viewer logic (Swift)
    └── [SETUP] req.Action ∈ viewer helper actions (format, details, prettify, poll)
    │
    ├── format-entry/                      LEAF: display line has timestamp, source, basename
    ├── format-command-executed/           LEAF: command.executed → 5 detail lines
    ├── format-command-executed-empty-io/  LEAF: empty stdout/stderr → (empty)
    ├── format-non-command-entry/          LEAF: event=stop → empty detail_lines
    ├── prettify-entry-json/               LEAF: pretty JSON with source, dir, indent
    ├── prettify-roundtrip/                LEAF: prettify then decode equals original
    └── poll-detects-new/                  LEAF: 1→2 entries on second poll
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Concern group | append, load, cap, migrate, api (Go) vs menu-label, viewer (Swift) |
| 2 | Action | `http_sequence`, `open_logs_menu_state`, `logs_viewer_menu_state`, viewer actions |
| 3 | Filesystem state | empty, seeded JSONL, legacy JSON array |
| 4 | Daemon reachability | success vs unreachable (menu-label only) |
| 5 | Isolation | temp state dir + ephemeral port; never `~/.os-bar/` |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `append/writes-jsonl-line/` | First log-only notify → 1 JSONL line with trailing `\n` |
| 2 | `append/second-append/` | Two appends → 2 lines; file is not a JSON array |
| 2b | `append/notification-click-logs-method/` | POST command log with `openMethod` round-trips to JSONL |
| 3 | `load/reads-jsonl/` | 3-line JSONL seed → daemon loads 3 entries via API |
| 4 | `cap/truncates-at-200/` | 201st entry → ≤200 lines on disk, oldest dropped |
| 5 | `migrate/legacy-json-array/` | Legacy `notify-logs.json` → `.jsonl`, `.json` removed |
| 6 | `api/returns-json-array/` | `GET /api/logs` returns JSON array body |
| 7 | `menu-label/finder-ok/` | Daemon OK → `Show Logs in Finder`, enabled |
| 8 | `menu-label/finder-error/` | Daemon error → `Show Logs in Finder (daemon unreachable)`, disabled |
| 9 | `menu-label/logs-viewer/` | `Logs` label, enabled=true even with error |
| 10 | `viewer/format-entry/` | Formatted row shows timestamp, source, dir basename |
| 11 | `viewer/poll-detects-new/` | Simulated poll: 1 entry then 2 entries |
| 12 | `viewer/format-command-executed/` | `command.executed` → 5 detail lines (cmd, exit, duration, I/O) |
| 13 | `viewer/format-command-executed-empty-io/` | Empty stdout/stderr → `(empty)` |
| 14 | `viewer/format-non-command-entry/` | `event=stop` → empty `detail_lines` |
| 15 | `viewer/prettify-entry-json/` | Pretty JSON with newlines, `"source"`, `"dir"` |
| 16 | `viewer/prettify-roundtrip/` | Prettified JSON decodes to equivalent entry |

## How to Run

```sh
cd macos-agent-sessions

# Validate tree structure
doctest vet ./tests/logs-jsonl

# Run all tests (RED until JSONL store + TestHelper actions exist)
doctest test ./tests/logs-jsonl

# Storage only (Go daemon harness)
doctest test ./tests/logs-jsonl/append/...
doctest test ./tests/logs-jsonl/load/...
doctest test ./tests/logs-jsonl/cap/...
doctest test ./tests/logs-jsonl/migrate/...
doctest test ./tests/logs-jsonl/api/...

# Menu + viewer only (Swift TestHelper)
doctest test ./tests/logs-jsonl/menu-label/...
doctest test ./tests/logs-jsonl/viewer/...

# Verbose
doctest test -v ./tests/logs-jsonl/...
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
	actionHTTPSequence         = "http_sequence"
	actionOpenLogsMenuState    = "open_logs_menu_state"
	actionLogsViewerMenuState  = "logs_viewer_menu_state"
	actionLogsViewerFormatEntry          = "logs_viewer_format_entry"
	actionLogsViewerFormatCommandDetails = "logs_viewer_format_command_details"
	actionLogsViewerPrettifyEntry        = "logs_viewer_prettify_entry"
	actionLogsViewerPollDetectsNew       = "logs_viewer_poll_detects_new"

	logFileNameJSONL   = "notify-logs.jsonl"
	logFileNameLegacy  = "notify-logs.json"
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

// CommandLogDetails mirrors NotifyLogEntry.command in store and TestHelper.
type CommandLogDetails struct {
	Command        string `json:"command"`
	ExitCode       int    `json:"exitCode"`
	Stdout         string `json:"stdout"`
	Stderr         string `json:"stderr"`
	DurationMs     int    `json:"durationMs"`
	OpenMethod     string `json:"openMethod,omitempty"`
	KoolAttempted  bool   `json:"koolAttempted,omitempty"`
	KoolIpcHandled bool   `json:"koolIpcHandled,omitempty"`
	FallbackReason string `json:"fallbackReason,omitempty"`
}

// NotifyLogEntry mirrors NotifyLogStore entries.
type NotifyLogEntry struct {
	Source    string               `json:"source"`
	Timestamp string               `json:"timestamp"`
	Dir       string               `json:"dir"`
	Event     string               `json:"event,omitempty"`
	Command   *CommandLogDetails   `json:"command,omitempty"`
}

// PollStep simulates one viewer poll cycle in TestHelper.
type PollStep struct {
	Entries []NotifyLogEntry `json:"entries,omitempty"`
}

// Request drives daemon HTTP and Swift test-helper actions. Defined only at root.
type Request struct {
	Action       string           `json:"action"`
	Port         int              `json:"port,omitempty"`
	StateDir     string           `json:"state_dir,omitempty"`
	HomeDir      string           `json:"home_dir,omitempty"`
	HTTPSteps    []HTTPStep       `json:"http_steps,omitempty"`
	StoragePath  string           `json:"storage_path,omitempty"`
	InfoError    string           `json:"info_error,omitempty"`
	LogEntry     *NotifyLogEntry  `json:"log_entry,omitempty"`
	PollSequence []PollStep       `json:"poll_sequence,omitempty"`
}

// Response captures daemon, menu, and viewer outcomes.
type Response struct {
	BaseURL         string           `json:"base_url,omitempty"`
	HTTPStatus      int              `json:"http_status,omitempty"`
	HTTPBody        string           `json:"http_body,omitempty"`
	LogEntries      []NotifyLogEntry `json:"log_entries,omitempty"`
	StateDir        string           `json:"state_dir,omitempty"`
	HomeDir         string           `json:"home_dir,omitempty"`
	Error           string           `json:"error,omitempty"`
	MenuLabel       string           `json:"menu_label,omitempty"`
	MenuEnabled     bool             `json:"menu_enabled,omitempty"`
	DisplayLine     string           `json:"display_line,omitempty"`
	DetailLines     []string         `json:"detail_lines,omitempty"`
	PrettyJSON      string           `json:"pretty_json,omitempty"`
	PollEntryCounts []int            `json:"poll_entry_counts,omitempty"`
	DetectedNew     bool             `json:"detected_new,omitempty"`
}

type daemonHandle struct {
	cmd      *exec.Cmd
	port     int
	baseURL  string
	binary   string
	stateDir string
	homeDir  string
}

var activeDaemon *daemonHandle

func buildDaemonBinary(t *testing.T) string {
	t.Helper()
	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")
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

func parseLogEntries(body string) []NotifyLogEntry {
	var entries []NotifyLogEntry
	_ = json.Unmarshal([]byte(body), &entries)
	return entries
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
		if step.Path == "/api/logs" || strings.HasPrefix(step.Path, "/api/logs?") {
			resp.LogEntries = parseLogEntries(body)
		}
	}
	return resp
}

func runSwiftTestHelper(t *testing.T, req *Request) (*Response, error) {
	t.Helper()
	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	helperPath := filepath.Join(projectRoot, ".build", "test-helper")
	helperSrc := filepath.Join(projectRoot, "os-bar-agent-sessionsTests", "TestHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("failed to build test helper: %w\n%s", err, out)
	}
	reqJSON, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}
	cmd := exec.Command(helperPath)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to get stdin pipe: %w", err)
	}
	go func() {
		defer stdin.Close()
		stdin.Write(reqJSON)
		stdin.Write([]byte("\n"))
	}()
	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("test helper failed (exit code %v): %w\n%s",
			cmd.ProcessState.ExitCode(), err, out)
	}
	var resp Response
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("failed to parse test helper output: %w\noutput: %s", err, out)
	}
	return &resp, nil
}

func logsJSONLPath(stateDir string) string {
	return filepath.Join(stateDir, logFileNameJSONL)
}

func logsLegacyPath(stateDir string) string {
	return filepath.Join(stateDir, logFileNameLegacy)
}

func readJSONLLines(t *testing.T, path string) []string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	raw := strings.Split(strings.TrimSuffix(string(data), "\n"), "\n")
	var lines []string
	for _, line := range raw {
		if strings.TrimSpace(line) != "" {
			lines = append(lines, line)
		}
	}
	return lines
}

func assertValidJSONLObjectLine(t *testing.T, line string) {
	t.Helper()
	line = strings.TrimSpace(line)
	if !strings.HasPrefix(line, "{") || !strings.HasSuffix(line, "}") {
		t.Fatalf("expected JSON object line, got %q", line)
	}
	var obj map[string]interface{}
	if err := json.Unmarshal([]byte(line), &obj); err != nil {
		t.Fatalf("invalid JSON on line: %v\nline: %s", err, line)
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

func Run(t *testing.T, req *Request) (*Response, error) {
	activeDaemon = nil

	switch req.Action {
	case actionOpenLogsMenuState, actionLogsViewerMenuState,
		actionLogsViewerFormatEntry, actionLogsViewerFormatCommandDetails,
		actionLogsViewerPrettifyEntry, actionLogsViewerPollDetectsNew:
		return runSwiftTestHelper(t, req)
	case actionHTTPSequence, "":
		if req.Action == "" {
			req.Action = actionHTTPSequence
		}
		binary := buildDaemonBinary(t)
		return runHTTPSequence(t, binary, req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
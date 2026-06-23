# Help Open Logs — Doc-Style Test Tree

Test suite for the **Open Logs** menu item (Help menu + menu-bar dropdown above
Settings). Validates daemon-only path resolution via `GET /api/info`, pure Finder
reveal planning (`notify-logs.json` vs state directory), and dynamic menu label /
enabled state when the daemon is reachable or unreachable.

No real Finder or UI automation in CI — assert HTTP info, plan, and label only.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **menu bar app** exposes **Open Logs** in two placements: the system **Help**
menu and the **menu-bar dropdown** above **Settings…**. Path resolution is
**daemon-only**: `storage_path ← GET /api/info` with **no** local/env fallback.

The **log file** lives at `{storage_path}/notify-logs.json` (Go `store.logsPath()`).
On click (daemon reachable): if the log file exists, Finder **selects** it via
`NSWorkspace.selectFile`; otherwise Finder **opens** `storage_path` as a directory.

On daemon error, **both** menu items show `Open Logs (daemon unreachable)` and are
**disabled**. Label refreshes on launch and when menus open.

The **Go doctest harness** starts an isolated `agent-sessions serve` process for
`info/` leaves (temp `--state-dir`, ephemeral port). The **Swift test helper**
(`TestHelper.swift`) mirrors pure `LogsFinderPlan` and `OpenLogsMenuState` logic
via JSON actions on stdin/stdout.

## Decision Tree

```
help-open-logs/                          ROOT: Request{Action, Port, StateDir, StoragePath, ...}
│                                                 Response{StoragePath, RevealKind, MenuLabel, ...}
│                                                 Run() routes daemon HTTP vs Swift test helper
│
├── info/                                DECISION: concern = daemon GET /api/info
│   └── [SETUP] req.Action ∈ {daemon_info, daemon_info_unreachable}
│   │
│   ├── success/                         LEAF: daemon running → storage_path
│   │   ├── SETUP → start daemon, GET /api/info
│   │   └── ASSERT → HTTP 200, storage_path == stateDir
│   │
│   └── unreachable/                     LEAF: no daemon on ephemeral port
│       ├── SETUP → GET /api/info without serve
│       └── ASSERT → error, storage_path empty
│
├── finder-plan/                         DECISION: concern = pure Finder reveal plan
│   └── [SETUP] req.Action = logs_finder_plan
│   │
│   ├── file-exists/                     LEAF: notify-logs.json present
│   │   ├── SETUP → seed log file under storage_path
│   │   └── ASSERT → reveal_kind=file, reveal_path=log, select_root=storage_path
│   │
│   └── file-missing/                    LEAF: empty state dir
│       ├── SETUP → storage_path only, no log file
│       └── ASSERT → reveal_kind=directory, reveal_path=storage_path
│
└── menu-label/                          DECISION: concern = menu label + enabled
    └── [SETUP] req.Action = open_logs_menu_state
    │
    ├── ok/                              LEAF: successful daemon info
    │   ├── SETUP → info_error empty
    │   └── ASSERT → label="Open Logs", enabled=true
    │
    └── daemon-error/                    LEAF: daemon unreachable
        ├── SETUP → info_error set
        └── ASSERT → label="Open Logs (daemon unreachable)", enabled=false
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Concern group | info (daemon HTTP), finder-plan (pure), menu-label (pure) |
| 2 | Action | `daemon_info`, `daemon_info_unreachable`, `logs_finder_plan`, `open_logs_menu_state` |
| 3 | Filesystem state | log file exists vs missing |
| 4 | Daemon reachability | success vs unreachable |
| 5 | Isolation | temp state dir + ephemeral port; never `~/.os-bar/` |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `info/success/` | `GET /api/info` returns 200; `storage_path` matches isolated `--state-dir` |
| 2 | `info/unreachable/` | No daemon on ephemeral port → connection error; `storage_path` empty |
| 3 | `finder-plan/file-exists/` | Seeded `notify-logs.json` → `reveal_kind=file`, select file in storage root |
| 4 | `finder-plan/file-missing/` | Empty state dir → `reveal_kind=directory`, open `storage_path` |
| 5 | `menu-label/ok/` | Successful info → label `Open Logs`, enabled |
| 6 | `menu-label/daemon-error/` | Info error → label `Open Logs (daemon unreachable)`, disabled |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Daemon info success | `info/success` | ✓ |
| Daemon unreachable | `info/unreachable` | ✓ |
| Finder: select log file | `finder-plan/file-exists` | ✓ |
| Finder: open state dir | `finder-plan/file-missing` | ✓ |
| Menu label when OK | `menu-label/ok` | ✓ |
| Menu label on error | `menu-label/daemon-error` | ✓ |

## How to Run

```sh
# Vet test tree structure
cd macos-agent-sessions && doctest vet ./tests/help-open-logs

# Run all tests (RED until DaemonClient.info + TestHelper actions exist)
cd macos-agent-sessions && doctest test ./tests/help-open-logs

# Run daemon info subtree only
cd macos-agent-sessions && doctest test ./tests/help-open-logs/info/...

# Run pure-logic subtrees only
cd macos-agent-sessions && doctest test ./tests/help-open-logs/finder-plan/...
cd macos-agent-sessions && doctest test ./tests/help-open-logs/menu-label/...

# Verbose
cd macos-agent-sessions && doctest test -v ./tests/help-open-logs/...
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
	actionDaemonInfo            = "daemon_info"
	actionDaemonInfoUnreachable = "daemon_info_unreachable"
	actionLogsFinderPlan        = "logs_finder_plan"
	actionOpenLogsMenuState     = "open_logs_menu_state"

	daemonReadyTimeout = 10 * time.Second
	daemonReadyPoll    = 50 * time.Millisecond

	logFileName = "notify-logs.json"
)

// Request drives daemon HTTP and Swift test-helper actions. Defined only at root.
type Request struct {
	Action       string `json:"action"`
	Port         int    `json:"port,omitempty"` // 0 = assign ephemeral
	StateDir     string `json:"state_dir,omitempty"`
	HomeDir      string `json:"home_dir,omitempty"`
	HTTPMethod   string `json:"http_method,omitempty"`
	HTTPPath     string `json:"http_path,omitempty"`
	StoragePath  string `json:"storage_path,omitempty"`
	SeedLogFile  bool   `json:"seed_log_file,omitempty"`
	InfoError    string `json:"info_error,omitempty"`
}

// Response captures daemon info, Finder plan, and menu state outcomes.
type Response struct {
	BaseURL     string `json:"base_url,omitempty"`
	HTTPStatus  int    `json:"http_status,omitempty"`
	HTTPBody    string `json:"http_body,omitempty"`
	StoragePath string `json:"storage_path,omitempty"`
	StateDir    string `json:"state_dir,omitempty"`
	HomeDir     string `json:"home_dir,omitempty"`
	Error       string `json:"error,omitempty"`
	RevealKind  string `json:"reveal_kind,omitempty"`
	RevealPath  string `json:"reveal_path,omitempty"`
	SelectRoot  string `json:"select_root,omitempty"`
	MenuLabel   string `json:"menu_label,omitempty"`
	MenuEnabled bool   `json:"menu_enabled,omitempty"`
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

func doHTTP(baseURL string, method, path string) (int, string, error) {
	if method == "" {
		method = http.MethodGet
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(baseURL + path)
	if method != http.MethodGet {
		httpReq, reqErr := http.NewRequest(method, baseURL+path, nil)
		if reqErr != nil {
			return 0, "", reqErr
		}
		resp, err = client.Do(httpReq)
	}
	if err != nil {
		return 0, "", err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(body), nil
}

func parseStoragePath(body string) string {
	var payload struct {
		StoragePath string `json:"storage_path"`
	}
	_ = json.Unmarshal([]byte(body), &payload)
	return payload.StoragePath
}

func runDaemonInfo(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	handle := ensureDaemon(t, binary, req)
	path := req.HTTPPath
	if path == "" {
		path = "/api/info"
	}
	status, body, err := doHTTP(handle.baseURL, req.HTTPMethod, path)
	if err != nil {
		return &Response{Error: err.Error(), StateDir: handle.stateDir, HomeDir: handle.homeDir}
	}
	return &Response{
		BaseURL:     handle.baseURL,
		HTTPStatus:  status,
		HTTPBody:    body,
		StoragePath: parseStoragePath(body),
		StateDir:    handle.stateDir,
		HomeDir:     handle.homeDir,
	}
}

func runDaemonInfoUnreachable(t *testing.T, req *Request) *Response {
	t.Helper()
	port := req.Port
	if port == 0 {
		port = pickEphemeralPort(t)
	}
	baseURL := fmt.Sprintf("http://127.0.0.1:%d", port)
	path := req.HTTPPath
	if path == "" {
		path = "/api/info"
	}
	status, body, err := doHTTP(baseURL, req.HTTPMethod, path)
	if err != nil {
		return &Response{
			BaseURL: baseURL,
			Error:   err.Error(),
		}
	}
	return &Response{
		BaseURL:     baseURL,
		HTTPStatus:  status,
		HTTPBody:    body,
		StoragePath: parseStoragePath(body),
		Error:       "expected connection error but request succeeded",
	}
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
	case actionLogsFinderPlan, actionOpenLogsMenuState:
		return runSwiftTestHelper(t, req)
	case actionDaemonInfoUnreachable:
		return runDaemonInfoUnreachable(t, req), nil
	case actionDaemonInfo, "":
		if req.Action == "" {
			req.Action = actionDaemonInfo
		}
		binary := buildDaemonBinary(t)
		return runDaemonInfo(t, binary, req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
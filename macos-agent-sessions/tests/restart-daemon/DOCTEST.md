# Restart Daemon Menu Item — Doc-Style Test Tree

Test suite for the **Restart Daemon** menu bar item. Validates label formatting
based on daemon port/PID state (live vs not-live) and the underlying daemon
restart logic in the Swift `TestHelper`.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **menu bar dropdown** shows a **Restart Daemon** button below "Auto Start"
toggle. The label format is:

- Daemon live: `Restart Daemon (Port: 38271, PID: 12345)`
- Daemon not live: `Restart Daemon (Port: -, PID: -)`
- PID missing: `Restart Daemon (Port: 38271, PID: -)`

Port comes from `AgentSessionsDaemonConfig.resolvedPort`. PID comes from
`AppDelegate.daemonProcess?.processIdentifier` (nil when not spawned or dead).

The **Swift TestHelper** exposes `restart_daemon_label` which computes the
label from given `daemon_port` and `daemon_pid` fields.

Clicking the button calls `AppDelegate.restartDaemon()` which:
1. Terminates current daemon (SIGTERM → SIGKILL)
2. Re-runs `ensureDaemonRunning()`

## Decision Tree

```
tests/restart-daemon/                      ROOT: Request{Action, DaemonPort, DaemonPID, ...}
│                                                   Response{ButtonLabel, ButtonEnabled, DaemonStopped, ...}
│                                                   Run() calls Swift test helper
│
├── label/                                 DECISION: concern = button label formatting
│   └── [SETUP] req.Action = restart_daemon_label
│   │
│   ├── live/                              LEAF: port=38271, pid=12345 → label with port+pid
│   ├── not-live/                          LEAF: port=-1, pid=-1 → label with -,-
│   ├── no-pid/                            LEAF: port=38271, pid=-1 → label with port only, PID -
│   └── always-enabled/                    LEAF: button is always enabled
│
└── restart/                               DECISION: concern = daemon lifecycle (Go daemon test)
    └── [SETUP] req.Action = daemon_restart
    │
    └── stops-and-restarts/                LEAF: SIGTERM old daemon, spawn new one, health becomes ok
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `label/live/` | Port=38271, PID=12345 → `Restart Daemon (Port: 38271, PID: 12345)` |
| 2 | `label/not-live/` | Port=-1, PID=-1 → `Restart Daemon (Port: -, PID: -)` |
| 3 | `label/no-pid/` | Port=38271, PID=-1 → `Restart Daemon (Port: 38271, PID: -)` |
| 4 | `label/always-enabled/` | Button always enabled regardless of daemon state |
| 5 | `restart/stops-and-restarts/` | Kill daemon → new health probe passes |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Label with live daemon | `label/live` | ✓ |
| Label with dead daemon | `label/not-live` | ✓ |
| Label with known port, unknown PID | `label/no-pid` | ✓ |
| Button always enabled | `label/always-enabled` | ✓ |
| Real daemon restart | `restart/stops-and-restarts` | ✓ |

## How to Run

```sh
cd macos-agent-sessions
doctest vet ./tests/restart-daemon
doctest test ./tests/restart-daemon
```

```go
import (
	"bytes"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"syscall"
	"testing"
	"time"
)

const (
	actionRestartDaemonLabel  = "restart_daemon_label"
	actionDaemonRestart       = "daemon_restart"

	daemonReadyTimeout = 20 * time.Second
	daemonReadyPoll    = 100 * time.Millisecond
)

type Request struct {
	Action     string `json:"action"`
	DaemonPort int    `json:"daemon_port"`
	DaemonPID  int    `json:"daemon_pid"`
}

type Response struct {
	Error        string `json:"error,omitempty"`
	ButtonLabel  string `json:"button_label,omitempty"`
	ButtonEnabled bool  `json:"button_enabled,omitempty"`
	DaemonStopped bool  `json:"daemon_stopped,omitempty"`
	DaemonAlive  bool   `json:"daemon_alive,omitempty"`
	BaseURL      string `json:"base_url,omitempty"`
	StateDir     string `json:"state_dir,omitempty"`
}

type daemonHandle struct {
	cmd      *exec.Cmd
	port     int
	baseURL  string
	binary   string
	stateDir string
}

func buildDaemonBinary(t *testing.T) string {
	t.Helper()
	binaryPath := filepath.Join(os.TempDir(), "agent-sessions-test-binary")
	if _, err := os.Stat(binaryPath); err == nil {
		return binaryPath
	}
	buildLockPath := filepath.Join(os.TempDir(), "agent-sessions-test-binary.lock")
	var lockFile *os.File
	for i := 0; i < 200; i++ {
		var err error
		lockFile, err = os.OpenFile(buildLockPath, os.O_CREATE|os.O_EXCL, 0644)
		if err == nil {
			break
		}
		if _, statErr := os.Stat(binaryPath); statErr == nil {
			return binaryPath
		}
		time.Sleep(100 * time.Millisecond)
	}
	if lockFile == nil {
		t.Fatalf("timed out waiting for build lock")
	}
	lockFile.Close()
	defer os.Remove(buildLockPath)
	if _, err := os.Stat(binaryPath); err == nil {
		return binaryPath
	}
	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")
	buildCmd := exec.Command("go", "build", "-o", binaryPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		t.Fatalf("go build agent-sessions: %v\n%s", err, out)
	}
	return binaryPath
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

func waitUntilDaemonDown(t *testing.T, baseURL string) bool {
	t.Helper()
	deadline := time.Now().Add(5 * time.Second)
	client := &http.Client{Timeout: 500 * time.Millisecond}
	for time.Now().Before(deadline) {
		resp, err := client.Get(baseURL + "/api/health")
		if err != nil {
			return true
		}
		resp.Body.Close()
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

func startDaemonProcess(t *testing.T, binary, stateDir string, port int) *daemonHandle {
	t.Helper()
	if port == 0 {
		port = pickEphemeralPort(t)
	}
	cmd := exec.Command(binary,
		"serve",
		"--port", strconv.Itoa(port),
		"--state-dir", stateDir,
	)
	cmd.Env = append(os.Environ(),
		"AGENT_SESSIONS_STATE_DIR="+stateDir,
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
	}
	t.Cleanup(func() {
		stopDaemonProcess(handle)
	})
	return handle
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

func runDaemonRestart(t *testing.T, req *Request) *Response {
	t.Helper()
	binary := buildDaemonBinary(t)
	stateDir := filepath.Join(t.TempDir(), "state")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		t.Fatalf("mkdir stateDir: %v", err)
	}
	handle := startDaemonProcess(t, binary, stateDir, 0)
	if !waitForDaemonReady(t, handle.baseURL) {
		t.Fatalf("daemon not ready")
	}
	// Kill the daemon (simulating restart)
	stopDaemonProcess(handle)
	down := waitUntilDaemonDown(t, handle.baseURL)
	// Start new daemon
	newHandle := startDaemonProcess(t, binary, stateDir, handle.port)
	alive := waitForDaemonReady(t, newHandle.baseURL)
	return &Response{
		DaemonStopped: down,
		DaemonAlive:   alive,
		BaseURL:       newHandle.baseURL,
		StateDir:      stateDir,
	}
}

func Run(t *testing.T, req *Request) (*Response, error) {
	switch req.Action {
	case actionRestartDaemonLabel:
		return runSwiftTestHelper(t, req)
	case actionDaemonRestart:
		return runDaemonRestart(t, req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
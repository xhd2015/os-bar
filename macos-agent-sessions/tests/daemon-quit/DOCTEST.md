# Daemon Quit on App Exit — Doc-Style Test Tree

Test suite for **daemon shutdown when the menu bar app quits**. The app calls
`DaemonShutdown.terminateOnQuit` from `applicationWillTerminate`, preferring a
spawned child `agent-sessions serve` process, then falling back to `daemon.pid`.

Swift **TestHelper** mirrors `DaemonShutdown` plan logic. Go **lifecycle**
leaves verify the daemon exits on `SIGTERM` (what the app sends on quit).

## Version

0.0.2

# DSN (Domain Specific Notion)

The **menu bar app** (`AppDelegate`) spawns or attaches to **agent-sessions
serve** on port `38271`. On Quit it must stop the daemon so hooks do not leave
an orphan listener.

**DaemonShutdown** resolves state dir (`AGENT_SESSIONS_STATE_DIR` or
`~/.os-bar/agent-sessions`), picks a quit **target** (spawned PID beats
`daemon.pid`), and signals `SIGTERM` then `SIGKILL` if needed. UI automation
launch (`-uiTestingOpenSettings`) skips shutdown.

**TestHelper** exposes `daemon_quit_plan` and `daemon_quit_should_terminate`
without launching the full app.

## Decision Tree

```
daemon-quit/                               ROOT: Request{Action, ...}, Response{QuitTargetKind, ...}
│                                                   Run() → Swift helper or Go daemon harness
│
├── plan/                                  DECISION: concern = quit target selection (Swift)
│   └── [SETUP] req.Action = daemon_quit_plan
│   │
│   ├── spawned-priority/                  LEAF: spawned PID wins over pid file
│   ├── pid-file-fallback/                 LEAF: no spawn → read daemon.pid
│   └── no-target/                         LEAF: no spawn, no pid file → none
│
├── state-dir/                             DECISION: concern = state dir resolution (Swift)
│   └── [SETUP] req.Action = daemon_quit_plan
│   │
│   ├── env-override/                      LEAF: AGENT_SESSIONS_STATE_DIR used
│   └── default-home/                      LEAF: default ~/.os-bar/agent-sessions
│
├── skip-ui-testing/                       LEAF: -uiTestingOpenSettings → no terminate
│
└── lifecycle/                             DECISION: concern = daemon SIGTERM (Go)
    └── [SETUP] req.Action = daemon_sigterm_shutdown
    │
    └── sigterm-stops-daemon/              LEAF: SIGTERM → health down, pid file removed
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `plan/spawned-priority/` | Spawned running PID chosen over pid file |
| 2 | `plan/pid-file-fallback/` | Pid file used when no spawned process |
| 3 | `plan/no-target/` | No shutdown target when both absent |
| 4 | `state-dir/env-override/` | Env overrides default state dir |
| 5 | `state-dir/default-home/` | Default state dir under home |
| 6 | `skip-ui-testing/` | UI test launch arg skips terminate |
| 7 | `lifecycle/sigterm-stops-daemon/` | SIGTERM stops daemon (Go integration) |

## How to Run

```sh
cd macos-agent-sessions
doctest vet ./tests/daemon-quit
doctest test ./tests/daemon-quit
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
	actionDaemonQuitPlan            = "daemon_quit_plan"
	actionDaemonQuitShouldTerminate = "daemon_quit_should_terminate"
	actionDaemonSigtermShutdown     = "daemon_sigterm_shutdown"

	daemonReadyTimeout = 10 * time.Second
	daemonReadyPoll    = 50 * time.Millisecond
)

type Request struct {
	Action            string   `json:"action"`
	SpawnedPID        *int     `json:"spawned_pid,omitempty"`
	SpawnedRunning    *bool    `json:"spawned_running,omitempty"`
	PIDFileContents   string   `json:"pid_file_contents,omitempty"`
	StateDirEnvValue  string   `json:"state_dir_env_value,omitempty"`
	Home              string   `json:"home,omitempty"`
	LaunchArguments   []string `json:"launch_arguments,omitempty"`
	Port              int      `json:"port,omitempty"`
	StateDir          string   `json:"state_dir,omitempty"`
}

type Response struct {
	Error                 string `json:"error,omitempty"`
	QuitTargetKind        string `json:"quit_target_kind,omitempty"`
	QuitTargetPID         int    `json:"quit_target_pid,omitempty"`
	StateDir              string `json:"state_dir,omitempty"`
	ShouldTerminateOnQuit bool   `json:"should_terminate_on_quit,omitempty"`
	DaemonStopped         bool   `json:"daemon_stopped,omitempty"`
	PIDFileRemoved        bool   `json:"pid_file_removed,omitempty"`
	TerminatedPID         int    `json:"terminated_pid,omitempty"`
	BaseURL               string `json:"base_url,omitempty"`
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
	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")
	binaryPath := filepath.Join(t.TempDir(), "agent-sessions")
	buildCmd := exec.Command("go", "build", "-o", binaryPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		t.Fatalf("go build agent-sessions: %v\n%s", err, out)
	}
	return binaryPath
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

func startDaemonProcess(t *testing.T, binary, stateDir string, port int) *daemonHandle {
	t.Helper()
	if port == 0 {
		port = pickEphemeralPort(t)
	}
	cmd := exec.Command(binary, "serve", "--port", strconv.Itoa(port), "--state-dir", stateDir)
	cmd.Env = append(os.Environ(), "AGENT_SESSIONS_STATE_DIR="+stateDir)
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
	handle := &daemonHandle{cmd: cmd, port: port, baseURL: baseURL, binary: binary, stateDir: stateDir}
	t.Cleanup(func() {
		if handle.cmd != nil && handle.cmd.Process != nil {
			_ = handle.cmd.Process.Kill()
			_ = handle.cmd.Wait()
		}
	})
	return handle
}

func runDaemonSigtermShutdown(t *testing.T, binary string, req *Request) *Response {
	t.Helper()
	stateDir := req.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(t.TempDir(), "state")
		if err := os.MkdirAll(stateDir, 0755); err != nil {
			t.Fatalf("mkdir stateDir: %v", err)
		}
	}
	handle := startDaemonProcess(t, binary, stateDir, req.Port)
	pidPath := filepath.Join(handle.stateDir, "daemon.pid")
	pidData, err := os.ReadFile(pidPath)
	if err != nil {
		t.Fatalf("read pid file: %v", err)
	}
	pid, err := strconv.Atoi(strings.TrimSpace(string(pidData)))
	if err != nil || pid <= 0 {
		t.Fatalf("invalid pid in %s: %q", pidPath, string(pidData))
	}
	proc, err := os.FindProcess(pid)
	if err != nil {
		t.Fatalf("find process %d: %v", pid, err)
	}
	if err := proc.Signal(syscall.SIGTERM); err != nil {
		t.Fatalf("signal SIGTERM to %d: %v", pid, err)
	}
	stopped := waitUntilDaemonDown(t, handle.baseURL)
	_, statErr := os.Stat(pidPath)
	pidRemoved := os.IsNotExist(statErr)
	handle.cmd = nil
	return &Response{
		BaseURL:        handle.baseURL,
		DaemonStopped:  stopped,
		PIDFileRemoved: pidRemoved,
		TerminatedPID:  pid,
	}
}

func Run(t *testing.T, req *Request) (*Response, error) {
	switch req.Action {
	case actionDaemonQuitPlan, actionDaemonQuitShouldTerminate:
		return runSwiftTestHelper(t, req)
	case actionDaemonSigtermShutdown:
		binary := buildDaemonBinary(t)
		return runDaemonSigtermShutdown(t, binary, req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
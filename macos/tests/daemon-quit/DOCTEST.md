# Daemon Quit on App Exit — Doc-Style Test Tree (os-bar)

Test suite for **daemon shutdown when the os-bar menu bar app quits**.
`SystemMonitor.terminateDaemon` (via `AppDelegate.applicationWillTerminate`)
uses `DaemonShutdown` to stop `os-bar-daemon serve` on port `38270`.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **os-bar app** spawns or attaches to **os-bar-daemon serve**. On Quit it
must terminate the metrics daemon. **DaemonShutdown** resolves
`OS_BAR_STATE_DIR` or `~/.os-bar/os-bar`, prefers a spawned child PID, then
reads `daemon.pid`.

**TestHelper** mirrors quit target selection. Go lifecycle leaf verifies
`SIGTERM` stops the daemon.

## Decision Tree

```
daemon-quit/                               ROOT
├── plan/
│   ├── spawned-priority/
│   ├── pid-file-fallback/
│   └── no-target/
├── state-dir/
│   ├── env-override/
│   └── default-home/
└── lifecycle/
    └── sigterm-stops-daemon/
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `plan/spawned-priority/` | Spawned PID wins |
| 2 | `plan/pid-file-fallback/` | Pid file fallback |
| 3 | `plan/no-target/` | No target |
| 4 | `state-dir/env-override/` | OS_BAR_STATE_DIR |
| 5 | `state-dir/default-home/` | Default ~/.os-bar/os-bar |
| 6 | `lifecycle/sigterm-stops-daemon/` | SIGTERM stops daemon |

## How to Run

```sh
cd macos
doctest vet ./tests/daemon-quit
doctest test ./tests/daemon-quit
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
	"strings"
	"syscall"
	"testing"
	"time"
)

const (
	actionDaemonQuitPlan        = "daemon_quit_plan"
	actionDaemonSigtermShutdown = "daemon_sigterm_shutdown"
	daemonReadyTimeout          = 10 * time.Second
	daemonReadyPoll             = 50 * time.Millisecond
)

type Request struct {
	Action           string `json:"action"`
	SpawnedPID       *int   `json:"spawned_pid,omitempty"`
	SpawnedRunning   *bool  `json:"spawned_running,omitempty"`
	PIDFileContents  string `json:"pid_file_contents,omitempty"`
	StateDirEnvValue string `json:"state_dir_env_value,omitempty"`
	Home             string `json:"home,omitempty"`
	Port             int    `json:"port,omitempty"`
	StateDir         string `json:"state_dir,omitempty"`
}

type Response struct {
	Error          string `json:"error,omitempty"`
	QuitTargetKind string `json:"quit_target_kind,omitempty"`
	QuitTargetPID  int    `json:"quit_target_pid,omitempty"`
	StateDir       string `json:"state_dir,omitempty"`
	DaemonStopped  bool   `json:"daemon_stopped,omitempty"`
	PIDFileRemoved bool   `json:"pid_file_removed,omitempty"`
	TerminatedPID  int    `json:"terminated_pid,omitempty"`
}

type daemonHandle struct {
	cmd      *exec.Cmd
	port     int
	baseURL  string
	stateDir string
}

func buildDaemonBinary(t *testing.T) string {
	t.Helper()
	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "os-bar")
	binaryPath := filepath.Join(t.TempDir(), "os-bar")
	buildCmd := exec.Command("go", "build", "-o", binaryPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		t.Fatalf("go build os-bar-daemon: %v\n%s", err, out)
	}
	return binaryPath
}

func runSwiftTestHelper(t *testing.T, req *Request) (*Response, error) {
	t.Helper()
	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	helperPath := filepath.Join(projectRoot, ".build", "test-helper")
	helperSrc := filepath.Join(projectRoot, "os-barTests", "TestHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("build test helper: %w\n%s", err, out)
	}
	reqJSON, _ := json.Marshal(req)
	cmd := exec.Command(helperPath)
	stdin, _ := cmd.StdinPipe()
	go func() {
		defer stdin.Close()
		stdin.Write(reqJSON)
		stdin.Write([]byte("\n"))
	}()
	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("test helper failed: %w\n%s", err, out)
	}
	var resp Response
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("parse helper output: %w\n%s", err, out)
	}
	return &resp, nil
}

func pickEphemeralPort(t *testing.T) int {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()
	return port
}

func waitForDaemonReady(t *testing.T, baseURL string) bool {
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
	deadline := time.Now().Add(5 * time.Second)
	client := &http.Client{Timeout: 500 * time.Millisecond}
	for time.Now().Before(deadline) {
		if _, err := client.Get(baseURL + "/api/health"); err != nil {
			return true
		}
		time.Sleep(daemonReadyPoll)
	}
	return false
}

func runDaemonSigtermShutdown(t *testing.T, binary string, req *Request) *Response {
	stateDir := req.StateDir
	if stateDir == "" {
		stateDir = filepath.Join(t.TempDir(), "state")
		_ = os.MkdirAll(stateDir, 0755)
	}
	port := req.Port
	if port == 0 {
		port = pickEphemeralPort(t)
	}
	cmd := exec.Command(binary, "serve", "--port", strconv.Itoa(port), "--state-dir", stateDir, "--mock-metrics")
	cmd.Env = append(os.Environ(), "OS_BAR_STATE_DIR="+stateDir)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		t.Fatalf("start daemon: %v", err)
	}
	baseURL := fmt.Sprintf("http://127.0.0.1:%d", port)
	if !waitForDaemonReady(t, baseURL) {
		_ = cmd.Process.Kill()
		t.Fatalf("daemon not ready: %s", stderr.String())
	}
	t.Cleanup(func() {
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
			_ = cmd.Wait()
		}
	})
	pidPath := filepath.Join(stateDir, "daemon.pid")
	pidData, err := os.ReadFile(pidPath)
	if err != nil {
		t.Fatalf("read pid: %v", err)
	}
	pid, _ := strconv.Atoi(strings.TrimSpace(string(pidData)))
	proc, _ := os.FindProcess(pid)
	_ = proc.Signal(syscall.SIGTERM)
	stopped := waitUntilDaemonDown(t, baseURL)
	_, statErr := os.Stat(pidPath)
	return &Response{
		DaemonStopped:  stopped,
		PIDFileRemoved: os.IsNotExist(statErr),
		TerminatedPID:  pid,
	}
}

func Run(t *testing.T, req *Request) (*Response, error) {
	switch req.Action {
	case actionDaemonQuitPlan:
		return runSwiftTestHelper(t, req)
	case actionDaemonSigtermShutdown:
		return runDaemonSigtermShutdown(t, buildDaemonBinary(t), req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
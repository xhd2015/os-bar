# Configurable Directory Open — Doc-Style Test Tree

Test suite for the **configurable open-method** feature of the `agent-sessions`
daemon. Validates the `GET /api/config`, `POST /api/config`, and
`POST /api/open-dir` endpoints: default behavior, read/write config persistence,
and dispatching to VS Code (`code`) or iTerm2 (`osascript`) based on the
configured or explicitly requested open method.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **Go daemon** (`agent-sessions serve`) stores per-user config in
`{stateDir}/config.json` as `{"open_method":"vscode" | "iterm2"}`. When the
config file is missing, `open_method` defaults to `"vscode"`.

The **`POST /api/open-dir`** endpoint accepts `{"dir":"<path>","open_method":"vscode|iterm2"}`.
When `open_method` is omitted it falls back to the daemon's config value.
The response is `{"ok":true,"open_method_used":"..."}` or `{"error":"..."}`.

The **`GET /api/config`** returns `{"open_method":"vscode"}`. The
**`POST /api/config`** accepts `{"open_method":"iterm2"}` and persists to disk.

For testing:
- The `code` binary path is overridden via `AGENT_SESSIONS_CODE_BINARY` env var,
  pointing to a mock script that records its arguments and exits 0.
- The iTerm2 library (`dot-pkgs/go-pkgs/shell/iterm2`) supports env-var injection
  via `KOOL_ITERM2_INSTALLED=1` and `KOOL_ITERM2_SCRIPT_OUT=<path>` so tests
  never call `osascript`.

The **Go doctest harness** starts an isolated `agent-sessions serve` process
for each daemon HTTP action (temp `--state-dir`, ephemeral port).

## Decision Tree

```
tests/dir-open/                                 ROOT: Request{Action, Dir, OpenMethod, CodeBinary, ...}
│                                                       Response{OK, OpenMethodUsed, Error, HTTPBody, ...}
│                                                       Run() starts daemon, routes actions
│
├── config/                                         DECISION: concern = config read/write behaviour
│   └── [SETUP] req.Action = config_get | config_set
│   │
│   ├── default-missing/                            LEAF: no config.json → open_method=vscode
│   ├── set-and-get/                                LEAF: POST iterm2 → GET returns iterm2
│   └── set-invalid/                                LEAF: POST invalid method → 400 error
│
└── open-dir/                                       DECISION: concern = open dir dispatch behaviour
    └── [SETUP] req.Action = open_dir
    │
    ├── vscode/                                     LEAF: POST open-dir {method:vscode} → code executed
    ├── iterm2/                                     LEAF: POST open-dir {method:iterm2} → script captured
    ├── missing-dir/                                LEAF: POST open-dir {} → 400 error
    ├── invalid-method/                             LEAF: POST open-dir {method:xxx} → 400 error
    ├── from-config/                                LEAF: config=iterm2, POST without method → iterm2
    └── explicit-override/                          LEAF: config=iterm2, POST with vscode → vscode
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `config/default-missing/` | No `config.json` → `GET /api/config` returns `open_method=vscode` |
| 2 | `config/set-and-get/` | `POST {method:iterm2}` → `GET` returns `iterm2` |
| 3 | `config/set-invalid/` | `POST {method:invalid}` → 400 error |
| 4 | `open-dir/vscode/` | `POST {method:vscode}` → mock `code` called with dir |
| 5 | `open-dir/iterm2/` | `POST {method:iterm2}` → AppleScript captured to file |
| 6 | `open-dir/missing-dir/` | `POST {}` → 400 error |
| 7 | `open-dir/invalid-method/` | `POST {method:xxx}` → 400 error |
| 8 | `open-dir/from-config/` | Config=iterm2, POST without method → uses iterm2 |
| 9 | `open-dir/explicit-override/` | Config=iterm2, POST with vscode → uses vscode |

## How to Run

```sh
cd macos-agent-sessions
doctest vet ./tests/dir-open
doctest test ./tests/dir-open
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
	actionConfigGet  = "config_get"
	actionConfigSet  = "config_set"
	actionOpenDir    = "open_dir"

	daemonReadyTimeout = 20 * time.Second
	daemonReadyPoll    = 100 * time.Millisecond
)

type Request struct {
	Action          string `json:"action"`
	Dir             string `json:"dir,omitempty"`
	OpenMethod      string `json:"open_method,omitempty"`
	Port            int    `json:"port,omitempty"`
	StateDir        string `json:"state_dir,omitempty"`
	CodeBinary      string `json:"code_binary,omitempty"`
	PreSetConfig    string `json:"pre_set_config,omitempty"`
	Iterm2Installed bool   `json:"iterm2_installed,omitempty"`
}

type Response struct {
	OK             bool   `json:"ok,omitempty"`
	OpenMethodUsed string `json:"open_method_used,omitempty"`
	Error          string `json:"error,omitempty"`
	HTTPStatus     int    `json:"http_status,omitempty"`
	HTTPBody       string `json:"http_body,omitempty"`
	CodeDirArg     string `json:"code_dir_arg,omitempty"`
	Iterm2Script   string `json:"iterm2_script,omitempty"`
	ConfigMethod   string `json:"config_method,omitempty"`
	StateDir       string `json:"state_dir,omitempty"`
	BaseURL        string `json:"base_url,omitempty"`
}

type daemonHandle struct {
	cmd      *exec.Cmd
	port     int
	baseURL  string
	binary   string
	stateDir string
}

// buildDaemonBinary builds (or finds a pre-built) agent-sessions binary.
// Uses a file lock at buildLockPath to serialize concurrent builds across processes.
func buildDaemonBinary(t *testing.T) string {
	t.Helper()
	binaryPath := filepath.Join(os.TempDir(), "agent-sessions-test-binary")
	buildLockPath := filepath.Join(os.TempDir(), "agent-sessions-test-binary.lock")

	// Fast path — already built
	if _, err := os.Stat(binaryPath); err == nil {
		return binaryPath
	}

	// Acquire file-based lock (cross-process safe via O_CREATE|O_EXCL)
	var lockFile *os.File
	for i := 0; i < 200; i++ {
		var err error
		lockFile, err = os.OpenFile(buildLockPath, os.O_CREATE|os.O_EXCL, 0644)
		if err == nil {
			break
		}
		// Another process holds the lock; wait and check if binary appeared
		if _, statErr := os.Stat(binaryPath); statErr == nil {
			return binaryPath
		}
		time.Sleep(100 * time.Millisecond)
	}
	if lockFile == nil {
		t.Fatalf("timed out waiting for build lock (20s)")
	}
	lockFile.Close()
	defer os.Remove(buildLockPath)

	// Double-check after acquiring lock
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

func createMockCodeBinary(t *testing.T, tempDir string) string {
	t.Helper()
	mockPath := filepath.Join(tempDir, "mock-code")
	if err := os.WriteFile(mockPath, []byte("#!/bin/bash\necho \"$@\" >&2\nexit 0\n"), 0755); err != nil {
		t.Fatalf("create mock code binary: %v", err)
	}
	return mockPath
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

func startDaemonProcess(t *testing.T, binary, stateDir string, port int, codeBinary string, iterm2Installed bool) *daemonHandle {
	t.Helper()
	if port == 0 {
		port = pickEphemeralPort(t)
	}
	cmd := exec.Command(binary,
		"serve",
		"--port", strconv.Itoa(port),
		"--state-dir", stateDir,
	)
	env := []string{
		"AGENT_SESSIONS_STATE_DIR=" + stateDir,
	}
	if codeBinary != "" {
		env = append(env, "AGENT_SESSIONS_CODE_BINARY="+codeBinary)
	}
	if iterm2Installed {
		env = append(env, "KOOL_ITERM2_INSTALLED=1")
	}
	cmd.Env = append(os.Environ(), env...)
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

func seedConfig(t *testing.T, stateDir, openMethod string) {
	t.Helper()
	cfg := map[string]string{"open_method": openMethod}
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		t.Fatalf("marshal config: %v", err)
	}
	cfgPath := filepath.Join(stateDir, "config.json")
	if err := os.WriteFile(cfgPath, data, 0644); err != nil {
		t.Fatalf("write config: %v", err)
	}
}

func startDaemonTest(t *testing.T, req *Request) *daemonHandle {
	t.Helper()
	stateDir := resolveStateDir(t, req)
	if req.PreSetConfig != "" {
		seedConfig(t, stateDir, req.PreSetConfig)
	}
	codeBinary := req.CodeBinary
	if codeBinary == "" {
		tempDir := t.TempDir()
		codeBinary = createMockCodeBinary(t, tempDir)
	}
	binary := buildDaemonBinary(t)
	return startDaemonProcess(t, binary, stateDir, req.Port, codeBinary, req.Iterm2Installed)
}

func doGet(baseURL, path string) (int, string, error) {
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(baseURL + path)
	if err != nil {
		return 0, "", err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(body), nil
}

func doPost(baseURL, path string, reqBody interface{}) (int, string, error) {
	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return 0, "", err
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Post(baseURL+path, "application/json", bytes.NewReader(bodyBytes))
	if err != nil {
		return 0, "", err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	return resp.StatusCode, string(respBody), nil
}

func runConfigGet(t *testing.T, req *Request) *Response {
	t.Helper()
	handle := startDaemonTest(t, req)
	status, body, err := doGet(handle.baseURL, "/api/config")
	if err != nil {
		return &Response{Error: err.Error(), StateDir: handle.stateDir, BaseURL: handle.baseURL}
	}
	var method string
	var payload struct {
		OpenMethod string `json:"open_method"`
	}
	if json.Unmarshal([]byte(body), &payload) == nil {
		method = payload.OpenMethod
	}
	return &Response{
		HTTPStatus:   status,
		HTTPBody:     body,
		ConfigMethod: method,
		StateDir:     handle.stateDir,
		BaseURL:      handle.baseURL,
	}
}

func runConfigSet(t *testing.T, req *Request) *Response {
	t.Helper()
	handle := startDaemonTest(t, req)
	status, body, err := doPost(handle.baseURL, "/api/config", map[string]string{
		"open_method": req.OpenMethod,
	})
	if err != nil {
		return &Response{Error: err.Error(), StateDir: handle.stateDir, BaseURL: handle.baseURL}
	}
	resp := &Response{
		HTTPStatus: status,
		HTTPBody:   body,
		StateDir:   handle.stateDir,
		BaseURL:    handle.baseURL,
	}
	if status == 200 {
		// Verify by reading config
		_, getBody, _ := doGet(handle.baseURL, "/api/config")
		var payload struct {
			OpenMethod string `json:"open_method"`
		}
		_ = json.Unmarshal([]byte(getBody), &payload)
		resp.ConfigMethod = payload.OpenMethod
		resp.HTTPBody = getBody
	}
	return resp
}

func runOpenDir(t *testing.T, req *Request) *Response {
	t.Helper()
	handle := startDaemonTest(t, req)
	body := map[string]string{}
	if req.Dir != "" {
		body["dir"] = req.Dir
	}
	if req.OpenMethod != "" {
		body["open_method"] = req.OpenMethod
	}
	status, respBody, err := doPost(handle.baseURL, "/api/open-dir", body)
	if err != nil {
		return &Response{Error: err.Error(), StateDir: handle.stateDir, BaseURL: handle.baseURL}
	}
	var payload struct {
		OK             bool   `json:"ok"`
		OpenMethodUsed string `json:"open_method_used"`
		Error          string `json:"error"`
	}
	_ = json.Unmarshal([]byte(respBody), &payload)
	return &Response{
		HTTPStatus:     status,
		HTTPBody:       respBody,
		OK:             payload.OK,
		OpenMethodUsed: payload.OpenMethodUsed,
		Error:          payload.Error,
		StateDir:       handle.stateDir,
		BaseURL:        handle.baseURL,
	}
}

func Run(t *testing.T, req *Request) (*Response, error) {
	switch req.Action {
	case actionConfigGet:
		return runConfigGet(t, req), nil
	case actionConfigSet:
		return runConfigSet(t, req), nil
	case actionOpenDir:
		return runOpenDir(t, req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
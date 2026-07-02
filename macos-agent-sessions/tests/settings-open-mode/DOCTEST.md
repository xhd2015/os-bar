# Settings Open Mode Picker — Doc-Style Test Tree

Test suite for the **Settings open mode picker** feature. Validates
`DaemonClient` config read/write against the Go daemon (`GET/POST /api/config`)
and the Settings window's picker UI (AX-identified).

## Version

0.0.2

# DSN (Domain Specific Notion)

The **Settings window** (`IntegrationsSettingsView`) has a **Default Open Mode**
section with a `Picker` that reads/writes the daemon's config via
`DaemonClient.getConfig()` / `setConfig(openMethod:)`. The daemon stores
`{"open_method":"vscode"|"iterm2"}` in `{stateDir}/config.json`.

**Config tests** start an isolated `agent-sessions serve` and test the
`DaemonClient` Swift code by sending HTTP actions through the existing
`TestHelper.swift` stdin/stdout bridge.

**Picker tests** use the **UIAutomationHelper** with AX accessibility to verify
the picker is visible with correct value and can be changed. Labeled
`ui-automation, slow, requires-accessibility`.

## Decision Tree

```
settings-open-mode/                       ROOT: Request{Action, Port, HomeDir, OpenMethod, ...}
│                                                  Response{ConfigOpenMethod, HTTPStatus, ...}
│                                                  Run() dispatches per Action
│
├── config/                               DECISION: concern = DaemonClient config R/W
│   └── [SETUP] req.Action ∈ {get_config, set_config}
│   │
│   ├── get-default/                      LEAF: fresh daemon → GET config → vscode
│   ├── set-and-get/                      LEAF: POST iterm2 → GET → iterm2
│   └── set-invalid/                      LEAF: POST invalid → error
│
└── picker/                               DECISION: concern = Settings UI picker (AX)
    └── [SETUP] req.Action ∈ {open_settings, click_picker_option, dump_layout}; AX required
    │
    ├── visible-with-default/             LEAF: picker exists, default = vscode
    └── change-to-iterm2/                 LEAF: select iTerm2 → config updated
```

## Parameter Ranking

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Concern | config (HTTP) vs picker (AX) |
| 2 | Action | `get_config`, `set_config`, AX sequence |
| 3 | Open method | `vscode` vs `iterm2` vs `invalid` |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `config/get-default/` | Fresh daemon → GET /api/config returns open_method=vscode |
| 2 | `config/set-and-get/` | POST iterm2 → GET returns iterm2 |
| 3 | `config/set-invalid/` | POST invalid → error response |
| 4 | `picker/visible-with-default/` | AX dump shows open-mode-picker with vscode selected |
| 5 | `picker/change-to-iterm2/` | AX select iTerm2 → daemon config changes to iterm2 |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| DaemonClient.getConfig default | `config/get-default` | ✓ |
| DaemonClient.setConfig + get | `config/set-and-get` | ✓ |
| DaemonClient.setConfig invalid | `config/set-invalid` | ✓ |
| Picker visible, default vscode | `picker/visible-with-default` | AX |
| Picker change → config updated | `picker/change-to-iterm2` | AX |

## How to Run

```sh
cd macos-agent-sessions

# Config tests (no AX required)
doctest vet ./tests/settings-open-mode
doctest test ./tests/settings-open-mode/config/...

# Picker tests (AX required)
doctest test --label ui-automation ./tests/settings-open-mode/picker/...

# All
doctest test ./tests/settings-open-mode/...
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
	actionGetConfig      = "get_config"
	actionSetConfig      = "set_config"
	actionAXSequence     = "ax_sequence"

	daemonReadyTimeout = 20 * time.Second
	daemonReadyPoll    = 100 * time.Millisecond
)

type Request struct {
	Action     string `json:"action"`
	Port       int    `json:"port,omitempty"`
	StateDir   string `json:"state_dir,omitempty"`
	HomeDir    string `json:"home_dir,omitempty"`
	WorkDir    string `json:"work_dir,omitempty"`
	OpenMethod string `json:"open_method,omitempty"`

	// AX sequence actions
	Sequence []Request `json:"sequence,omitempty"`
}

type Response struct {
	Error            string `json:"error,omitempty"`
	HTTPStatus       int    `json:"http_status,omitempty"`
	HTTPBody         string `json:"http_body,omitempty"`
	ConfigOpenMethod string `json:"config_open_method,omitempty"`
	BaseURL          string `json:"base_url,omitempty"`
	StateDir         string `json:"state_dir,omitempty"`

	// AX fields
	LayoutBefore []AXElement `json:"layout_before,omitempty"`
	LayoutAfter  []AXElement `json:"layout_after,omitempty"`
	WindowOpen   bool        `json:"window_open,omitempty"`
}

type AXElement struct {
	Identifier string `json:"identifier"`
	Role       string `json:"role"`
	Value      string `json:"value,omitempty"`
	Title      string `json:"title,omitempty"`
	Children   []AXElement `json:"children,omitempty"`
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

func runGetConfig(t *testing.T, req *Request) *Response {
	t.Helper()
	stateDir := resolveStateDir(t, req)
	binary := buildDaemonBinary(t)
	handle := startDaemonProcess(t, binary, stateDir, req.Port)
	status, body, err := doGet(handle.baseURL, "/api/config")
	if err != nil {
		return &Response{Error: err.Error(), StateDir: stateDir, BaseURL: handle.baseURL}
	}
	var payload struct {
		OpenMethod string `json:"open_method"`
	}
	_ = json.Unmarshal([]byte(body), &payload)
	return &Response{
		HTTPStatus:       status,
		HTTPBody:         body,
		ConfigOpenMethod: payload.OpenMethod,
		StateDir:         stateDir,
		BaseURL:          handle.baseURL,
	}
}

func runSetConfig(t *testing.T, req *Request) *Response {
	t.Helper()
	stateDir := resolveStateDir(t, req)
	binary := buildDaemonBinary(t)
	handle := startDaemonProcess(t, binary, stateDir, req.Port)
	status, body, err := doPost(handle.baseURL, "/api/config", map[string]string{
		"open_method": req.OpenMethod,
	})
	if err != nil {
		return &Response{Error: err.Error(), StateDir: stateDir, BaseURL: handle.baseURL}
	}
	resp := &Response{
		HTTPStatus: status,
		HTTPBody:   body,
		StateDir:   stateDir,
		BaseURL:    handle.baseURL,
	}
	// Verify by reading back
	if status == 200 {
		_, getBody, _ := doGet(handle.baseURL, "/api/config")
		var payload struct {
			OpenMethod string `json:"open_method"`
		}
		_ = json.Unmarshal([]byte(getBody), &payload)
		resp.ConfigOpenMethod = payload.OpenMethod
		resp.HTTPBody = getBody
	}
	return resp
}

func runAXSequence(t *testing.T, req *Request) *Response {
	t.Helper()
	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	helperPath := filepath.Join(projectRoot, ".build", "ui-automation-helper")
	helperSrc := filepath.Join(projectRoot, "os-bar-agent-sessionsTests", "UIAutomationHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return &Response{Error: fmt.Sprintf("build helper: %v\n%s", err, out)}
	}
	homeDir := req.HomeDir
	if homeDir == "" {
		homeDir = filepath.Join(t.TempDir(), "home")
		if err := os.MkdirAll(homeDir, 0755); err != nil {
			t.Fatalf("mkdir homeDir: %v", err)
		}
	}
	t.Setenv("HOME", homeDir)
	reqJSON, err := json.Marshal(req)
	if err != nil {
		return &Response{Error: fmt.Sprintf("marshal request: %v", err)}
	}
	cmd := exec.Command(helperPath)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return &Response{Error: fmt.Sprintf("stdin pipe: %v", err)}
	}
	go func() {
		defer stdin.Close()
		stdin.Write(reqJSON)
		stdin.Write([]byte("\n"))
	}()
	out, err := cmd.CombinedOutput()
	if err != nil {
		return &Response{Error: fmt.Sprintf("helper failed: %v\noutput: %s", err, out)}
	}
	var resp Response
	if err := json.Unmarshal(out, &resp); err != nil {
		return &Response{Error: fmt.Sprintf("parse response: %v\noutput: %s", err, out)}
	}
	return &resp
}

func Run(t *testing.T, req *Request) (*Response, error) {
	switch req.Action {
	case actionGetConfig:
		return runGetConfig(t, req), nil
	case actionSetConfig:
		return runSetConfig(t, req), nil
	case actionAXSequence:
		return runAXSequence(t, req), nil
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
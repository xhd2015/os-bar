# Notification Click UI — Doc-Style Test Tree

End-to-end UI test: launch `.app` bundle, post session notify, click the macOS
notification via Accessibility, capture unified logs (`log show`) and app debug log
file (`[NotificationClick]`).

## Version

0.0.3

# DSN (Domain Specific Notion)

The **menu bar app** (`.app` bundle required for `UNUserNotificationCenter`) polls
the daemon, posts a user notification, and handles click → `code <dir>` → VS Code
activation. **UI automation helper** launches the test bundle, POSTs `/api/notify`,
searches Notification Center AX tree for `Agent session finished`, clicks it, then
runs `log show` plus reads `AGENT_SESSIONS_NOTIFICATION_DEBUG_LOG`.

## Decision Tree

```
notification-click-ui/                   ROOT: Request{Action, NotifyDir, ...}
│                                                 Response{NotificationClicked, LogLines, ...}
│
└── e2e/                                 DECISION: layer = end-to-end UI
    ├── click-captures-logs/             LEAF: auto-click notification + log capture
    ├── post-notification-manual-click/    LEAF: POST notify, user clicks, log capture
    └── window-focus-manual/             LEAF: two-round human-assisted window focus parity
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `e2e/click-captures-logs/` | Auto-click notification; capture `[NotificationClick]` + VS Code logs |
| 2 | `e2e/post-notification-manual-click/` | Send notification; wait for manual click; capture logs |
| 3 | `e2e/window-focus-manual/` | Modals + two notifications; verify cross-Space window focus |

## How to Run

```sh
cd macos-agent-sessions

# Requires Accessibility permission for test runner + notification permission for ui-test app
doctest vet ./tests/notification-click-ui
doctest test -v ./tests/notification-click-ui/e2e/post-notification-manual-click
doctest test -v ./tests/notification-click-ui/e2e/window-focus-manual
doctest test -v ./tests/notification-click-ui/...

# Manual log tail during run:
log stream --predicate 'eventMessage CONTAINS "[NotificationClick]"' --style compact
```

```go
import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const (
	axErrorAPIDisabled              = "-25211"
	uiAutomationTimeout             = 90 * time.Second
	uiManualClickTimeout            = 180 * time.Second
	uiWindowFocusManualTimeout      = 25 * time.Minute
	actionNotificationClick         = "notification_click_e2e"
	actionNotificationPostManual    = "notification_post_manual_click"
	actionNotificationWindowFocus   = "notification_window_focus_manual"
)

type Request struct {
	Action                 string `json:"action"`
	HomeDir                string `json:"home_dir,omitempty"`
	StateDir               string `json:"state_dir,omitempty"`
	WorkDir                string `json:"work_dir,omitempty"`
	NotifyDir              string `json:"notify_dir,omitempty"`
	NotificationTitle      string `json:"notification_title,omitempty"`
	LogCaptureSeconds      int    `json:"log_capture_seconds,omitempty"`
	ManualClickWaitSeconds int    `json:"manual_click_wait_seconds,omitempty"`
}

type Response struct {
	Error                     string   `json:"error,omitempty"`
	HomeDir                   string   `json:"home_dir,omitempty"`
	WorkDir                   string   `json:"work_dir,omitempty"`
	NotificationPosted        bool     `json:"notification_posted"`
	NotificationClicked       bool     `json:"notification_clicked"`
	ClickOK                   bool     `json:"click_ok"`
	LogLines                  []string `json:"log_lines"`
	NotificationClickLogLines []string `json:"notification_click_log_lines"`
	VSCodeLogLines            []string `json:"vscode_log_lines"`
	AppLogPath                string   `json:"app_log_path"`
	AppLogLines               []string `json:"app_log_lines"`
	NotificationAuthorized    bool     `json:"notification_authorized"`
	NotificationAuthStatus       string `json:"notification_auth_status"`
	NotificationBundleID         string `json:"notification_bundle_id"`
	FirstNotificationClicked     bool   `json:"first_notification_clicked"`
	SecondNotificationClicked    bool   `json:"second_notification_clicked"`
	UserConfirmedWindowOpened    bool   `json:"user_confirmed_window_opened"`
	UserConfirmedDesktopReady    bool   `json:"user_confirmed_desktop_ready"`
	UserConfirmedCorrectWindow   bool   `json:"user_confirmed_correct_window"`
	UserReportWindowOpened       string `json:"user_report_window_opened,omitempty"`
	UserReportDesktopReady       string `json:"user_report_desktop_ready,omitempty"`
	UserReportCorrectWindow      string `json:"user_report_correct_window,omitempty"`
	HumanAssistedPassed          bool   `json:"human_assisted_passed"`
}

func buildUIHelper(projectRoot string) (string, error) {
	helperPath := filepath.Join(projectRoot, ".build", "ui-automation-helper")
	helperSrc := filepath.Join(projectRoot, "os-bar-agent-sessionsTests", "UIAutomationHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("build ui-automation-helper: %w\n%s", err, out)
	}
	return helperPath, nil
}

func runUIAutomation(t *testing.T, req *Request, projectRoot, homeDir, stateDir, workDir string, timeout time.Duration) (*Response, error) {
	helperPath, err := buildUIHelper(projectRoot)
	if err != nil {
		return nil, err
	}

	req.HomeDir = homeDir
	req.StateDir = stateDir
	req.WorkDir = workDir
	reqJSON, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	cmd := exec.Command(helperPath)
	cmd.Env = os.Environ()
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		return nil, err
	}
	go func() {
		defer stdin.Close()
		stdin.Write(reqJSON)
		stdin.Write([]byte("\n"))
	}()

	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	select {
	case err := <-done:
		if err != nil {
			combined := stdout.String() + "\n" + stderr.String()
			if strings.Contains(combined, axErrorAPIDisabled) {
				t.Skip("Accessibility API disabled; enable Accessibility for test runner")
			}
			return nil, fmt.Errorf("ui-automation-helper failed: %w\n%s", err, combined)
		}
	case <-time.After(timeout):
		_ = cmd.Process.Kill()
		<-done
		combined := stdout.String() + "\n" + stderr.String()
		return nil, fmt.Errorf("ui-automation-helper timed out after %s\n%s", timeout, combined)
	}

	var resp Response
	if err := json.Unmarshal(stdout.Bytes(), &resp); err != nil {
		return nil, fmt.Errorf("parse response: %w\noutput: %s", err, stdout.String())
	}
	if resp.Error != "" {
		if strings.Contains(resp.Error, axErrorAPIDisabled) {
			t.Skip("Accessibility API disabled; enable Accessibility for test runner")
		}
		return &resp, fmt.Errorf("ui-automation-helper error: %s", resp.Error)
	}
	return &resp, nil
}

func Run(t *testing.T, req *Request) (*Response, error) {
	realHome, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	stateDir := filepath.Join(t.TempDir(), "agent-sessions-state")
	workDir := filepath.Join(t.TempDir(), "proj")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return nil, err
	}
	if req.HomeDir == "" {
		req.HomeDir = realHome
	}
	if req.StateDir == "" {
		req.StateDir = stateDir
	}
	if req.WorkDir == "" {
		req.WorkDir = workDir
	}
	if req.NotifyDir == "" {
		req.NotifyDir = workDir
	}
	if req.NotificationTitle == "" {
		req.NotificationTitle = "Agent session finished"
	}
	if req.LogCaptureSeconds == 0 {
		req.LogCaptureSeconds = 20
	}
	if req.ManualClickWaitSeconds == 0 {
		req.ManualClickWaitSeconds = 120
	}

	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")

	switch req.Action {
	case actionNotificationClick:
		return runUIAutomation(t, req, projectRoot, req.HomeDir, req.StateDir, workDir, uiAutomationTimeout)
	case actionNotificationPostManual:
		return runUIAutomation(t, req, projectRoot, req.HomeDir, req.StateDir, workDir, uiManualClickTimeout)
	case actionNotificationWindowFocus:
		return runUIAutomation(t, req, projectRoot, req.HomeDir, req.StateDir, workDir, uiWindowFocusManualTimeout)
	default:
		return nil, fmt.Errorf("unknown action %q", req.Action)
	}
}
```
# Scenario

**Feature**: UI tests for macOS session notifications and debug log capture

```
# auto-click path
notification_click_e2e -> AX click banner -> log capture

# manual-click path (you click the banner when prompted)
notification_post_manual_click -> POST notify -> wait for your click -> log capture
```

## Preconditions

- Swift UI automation helper at `.build/ui-automation-helper`.
- Test `.app` bundle built at `.build/ui-test/os-bar-agent-sessions.app` (notifications require bundle).
- Accessibility permission for the test runner (auto-click leaf only).
- Notification permission for `com.os-bar.agent-sessions.ui-test` (System Settings → Notifications).

## Steps

1. Create isolated `fakeHome` and `workDir` under `t.TempDir()`.
2. Build UI helper, send `notification_click_e2e` JSON on stdin.
3. Parse response with `log_lines`, `notification_click_log_lines`, `vscode_log_lines`, `app_log_lines`.

## Context

- Uses `log show` (same family as `log stream`) for unified log capture.
- App debug log file: `$HOME/.os-bar/notification-click-ui.log` via `AGENT_SESSIONS_NOTIFICATION_DEBUG_LOG`.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("notification-click-ui: root setup")
	return nil
}
```
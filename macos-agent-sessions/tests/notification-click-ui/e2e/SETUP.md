# Scenario

**Feature**: end-to-end notification click with log capture

```
# full UI path from app launch through notification click and log harvest
notification_click_e2e(notify_dir) -> notification_clicked, notification_click_log_lines, vscode_log_lines
```

## Preconditions

- Same as root; leaf asserts on captured logs after click attempt.

## Steps

- Leaf sets `action: notification_click_e2e` with `notify_dir` = `workDir`.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("notification-click-ui/e2e: end-to-end notification click")
	return nil
}
```
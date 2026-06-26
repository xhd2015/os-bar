# Scenario

**Feature**: POST session notify and wait for human to click the banner

```
# launch .app -> POST /api/notify -> macOS notification -> YOU click -> logs captured
notification_post_manual_click -> notification_posted=true, then wait for click in app log
```

## Preconditions

- Notifications enabled for `com.os-bar.agent-sessions.ui-test`.
- You will click the banner when the test prints `NOTIFICATION READY — CLICK IT NOW`.
- No Accessibility required for this leaf (automation does not click).

## Steps

1. Set `action` to `notification_post_manual_click`.
2. Default `manual_click_wait_seconds` is 120.
3. When prompted in test output, click the `Agent session finished` notification.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_post_manual_click"
	req.ManualClickWaitSeconds = 120
	return nil
}
```
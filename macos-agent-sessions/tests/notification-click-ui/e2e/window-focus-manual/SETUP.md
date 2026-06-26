# Scenario

**Feature**: Human-assisted notification window focus across macOS Spaces

```
# notify -> click -> confirm opened -> move Space -> notify -> click -> confirm focus
notification_window_focus_manual -> modals orchestrate two-round parity check
```

## Preconditions

- `./script/install-debug.sh --no-open` installed.
- Notifications enabled for `com.os-bar.agent-sessions.debug`.
- VS Code installed (`/usr/local/bin/code`).
- You will respond to modal dialogs and click two notification banners.

## Steps

1. Set `action` to `notification_window_focus_manual`.
2. Default `manual_click_wait_seconds` is 180 per click round.
3. Follow modal prompts: confirm window opened, move to another Space, click second banner, confirm correct window.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_window_focus_manual"
	req.ManualClickWaitSeconds = 180
	return nil
}
```
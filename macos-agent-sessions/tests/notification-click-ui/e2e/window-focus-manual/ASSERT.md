---
label: human-guided-ui-test, slow
explanation: Human-assisted two-round test with modals and two notification clicks across Spaces to verify VS Code window focus parity (up to 25 min).
---

## Expected

- `resp.Error == ""`.
- `resp.HumanAssistedPassed == true`.
- `resp.FirstNotificationClicked == true` and `resp.SecondNotificationClicked == true`.
- `resp.UserConfirmedWindowOpened`, `UserConfirmedDesktopReady`, `UserConfirmedCorrectWindow` all true.

## Side Effects

- Two macOS notifications from the debug app; two manual clicks required.
- Modal dialogs block until you respond.

## Errors

- Any modal "No" or "Cancel" fails the test with a descriptive `resp.Error`.
- **Customize** free-text reports set `resp.UserReport*` fields and fail with `user custom report (...)` in `resp.Error`.
- Click timeout per round fails before modals complete.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		if strings.Contains(resp.Error, "notification not authorized") {
			t.Fatalf("NOTIFICATION PERMISSION: %s\nEnable System Settings → Notifications → %q\napp_log_path=%q",
				resp.Error, resp.NotificationBundleID, resp.AppLogPath)
		}
		t.Fatalf("test helper reported error: %s", resp.Error)
	}
	if !resp.HumanAssistedPassed {
		t.Fatalf("expected human_assisted_passed=true\nfirst_click=%v second_click=%v window_opened=%v desktop_ready=%v correct_window=%v\napp_log_path=%q\nsample:\n%s",
			resp.FirstNotificationClicked, resp.SecondNotificationClicked,
			resp.UserConfirmedWindowOpened, resp.UserConfirmedDesktopReady, resp.UserConfirmedCorrectWindow,
			resp.AppLogPath, truncateLines(resp.AppLogLines, 40))
	}
	if !resp.FirstNotificationClicked || !resp.SecondNotificationClicked {
		t.Fatalf("expected both notification clicks detected in app log")
	}
	if !resp.UserConfirmedWindowOpened || !resp.UserConfirmedDesktopReady || !resp.UserConfirmedCorrectWindow {
		t.Fatal("expected all human confirmation steps to be affirmed")
	}
	combined := strings.Join(resp.AppLogLines, "\n")
	if strings.Count(combined, "delegate_did_receive") < 2 {
		t.Fatalf("expected at least 2 delegate_did_receive entries in app log\nsample:\n%s",
			truncateLines(resp.AppLogLines, 40))
	}
	t.Logf("window-focus-manual OK: app_log=%s", resp.AppLogPath)
}

func truncateLines(lines []string, max int) string {
	if len(lines) > max {
		lines = lines[:max]
	}
	return strings.Join(lines, "\n")
}
```
---
label: human-guided-ui-test, slow
explanation: Posts session notification then waits up to 180s for you to click the banner; captures app debug log and VS Code log lines.
---

## Expected

- `resp.Error == ""`.
- `resp.NotificationPosted == true` — daemon accepted POST /api/notify.
- `resp.NotificationClicked == true` — you clicked within the wait window (detected via app log).
- App log contains `[NotificationClick]` and `delegate_did_receive`.

## Side Effects

- Sends a real macOS user notification from the ui-test app bundle.
- Blocks up to `manual_click_wait_seconds` for your click.

## Errors

- `notification_posted=false` means notify never reached the daemon.
- `notification_clicked=false` means no click detected before timeout.

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
			t.Fatalf("NOTIFICATION PERMISSION: %s\nEnable System Settings → Notifications → %q → Allow Notifications (Banners/Alerts)\napp_log_path=%q\nsample:\n%s",
				resp.Error, resp.NotificationBundleID, resp.AppLogPath, truncateLines(resp.AppLogLines, 30))
		}
		t.Fatalf("test helper reported error: %s", resp.Error)
	}
	if !resp.NotificationPosted {
		t.Fatal("expected notification_posted=true — POST /api/notify should succeed")
	}
	if !resp.NotificationClicked {
		t.Fatalf("no manual click detected within %ds — click the banner when prompted\napp_log_path=%q\nsample:\n%s",
			req.ManualClickWaitSeconds, resp.AppLogPath, truncateLines(resp.AppLogLines, 40))
	}

	combined := strings.Join(append(resp.AppLogLines, resp.NotificationClickLogLines...), "\n")
	if !strings.Contains(combined, "[NotificationClick]") {
		t.Fatalf("expected [NotificationClick] in app log after manual click\napp_log_path=%q\nsample:\n%s",
			resp.AppLogPath, truncateLines(resp.AppLogLines, 40))
	}
	if !strings.Contains(combined, "delegate_did_receive") {
		t.Fatalf("expected delegate_did_receive after manual click\nsample:\n%s", truncateLines(resp.AppLogLines, 40))
	}
	t.Logf("post-notification-manual-click OK: app_log=%s vscode_log_lines=%d",
		resp.AppLogPath, len(resp.VSCodeLogLines))
}

func truncateLines(lines []string, max int) string {
	if len(lines) > max {
		lines = lines[:max]
	}
	return strings.Join(lines, "\n")
}
```
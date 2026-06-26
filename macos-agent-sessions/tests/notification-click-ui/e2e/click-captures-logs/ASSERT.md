---
label: ui-automation, slow, requires-accessibility
explanation: Launches debug .app bundle, auto-clicks notification via AX, captures unified logs (~90s). Requires Accessibility for test runner and notification permission for debug app.
---

## Expected

- `resp.Error == ""`.
- `resp.NotificationPosted == true`.
- If `resp.NotificationClicked == false`, test fails with captured logs (banner not found — check notification permission).
- When clicked, combined logs contain `[NotificationClick]`, `delegate_did_receive`, and VS Code / code-process lines.

## Side Effects

- Launches ui-test app bundle, posts notify, attempts real notification click, captures `log show` output.

## Errors

- Missing `[NotificationClick]` lines means debug logging did not reach unified log or app log file.
- Click succeeded but no `code_process_*` lines indicates click handler did not run open-session flow.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("test helper reported error: %s", resp.Error)
	}
	if !resp.NotificationPosted {
		t.Fatal("expected notification_posted=true after POST /api/notify")
	}

	allLogs := append(append([]string{}, resp.NotificationClickLogLines...), resp.AppLogLines...)
	if len(resp.LogLines) > 0 {
		allLogs = append(allLogs, resp.LogLines...)
	}
	combined := strings.Join(allLogs, "\n")

	if !resp.NotificationClicked {
		t.Fatalf("notification banner not clicked (enable Notifications for com.os-bar.agent-sessions.ui-test; keep banner visible during test)\napp_log_path=%q\nunified_log_lines=%d app_log_lines=%d\nsample:\n%s",
			resp.AppLogPath, len(resp.LogLines), len(resp.AppLogLines), truncateLines(allLogs, 60))
	}

	if !strings.Contains(combined, "[NotificationClick]") {
		t.Fatalf("expected [NotificationClick] in logs; notification_click_log_lines=%d app_log_lines=%d log_lines=%d app_log_path=%q\nsample:\n%s",
			len(resp.NotificationClickLogLines), len(resp.AppLogLines), len(resp.LogLines), resp.AppLogPath, truncateLines(allLogs, 40))
	}
	if !strings.Contains(combined, "delegate_did_receive") {
		t.Fatalf("expected delegate_did_receive in notification click logs\nsample:\n%s", truncateLines(allLogs, 40))
	}

	hasCodeFlow := strings.Contains(combined, "code_process_started") ||
		strings.Contains(combined, "code_process_finished") ||
		strings.Contains(combined, "open_dir_launch")
	hasVSCode := strings.Contains(combined, "vscode_activation") ||
		strings.Contains(strings.ToLower(combined), "vscode")

	if !hasCodeFlow {
		t.Fatalf("expected code_process_* or open_dir_launch after notification click\nsample:\n%s", truncateLines(allLogs, 40))
	}
	if !hasVSCode {
		t.Fatalf("expected vscode-related log lines after notification click\nsample:\n%s", truncateLines(allLogs, 40))
	}

	t.Logf("click-captures-logs OK: click_log_lines=%d vscode_log_lines=%d app_log=%s",
		len(resp.NotificationClickLogLines), len(resp.VSCodeLogLines), resp.AppLogPath)
}

func truncateLines(lines []string, max int) string {
	if len(lines) > max {
		lines = lines[:max]
	}
	return strings.Join(lines, "\n")
}
```
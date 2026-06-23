# Scenario

**Feature**: format command detail lines for `command.executed` entries

```
# entry with full CommandLogDetails
event=command.executed, command + exit 0 + duration + stdout + stderr
→ 5 detail lines (command, exit code, duration, stdout, stderr)
```

## Steps

1. Set `req.LogEntry` with `event: "command.executed"` and populated `command` struct.
2. Call `logs_viewer_format_command_details` via Swift test helper.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsViewerFormatCommandDetails
	req.LogEntry = &NotifyLogEntry{
		Source:    "log",
		Timestamp: "2026-06-23T12:00:00Z",
		Dir:       "/Users/me/proj/my-app",
		Event:     "command.executed",
		Command: &CommandLogDetails{
			Command:    "/usr/local/bin/code /Users/me/proj/my-app",
			ExitCode:   0,
			Stdout:     "opened editor",
			Stderr:     "warn: stale lock",
			DurationMs: 123,
		},
	}
	return nil
}
```
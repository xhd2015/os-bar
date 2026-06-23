# Scenario

**Feature**: empty stdout/stderr render as `(empty)` in command details

```
# command.executed with blank stdout and stderr
→ stdout/stderr detail lines show "(empty)"
```

## Steps

1. Set `req.LogEntry` with `command.executed` and empty `stdout`/`stderr`.
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
			Stdout:     "",
			Stderr:     "",
			DurationMs: 50,
		},
	}
	return nil
}
```
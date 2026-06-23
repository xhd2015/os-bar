# Scenario

**Feature**: prettified JSON decodes back to equivalent log entry fields

```
# entry with command details
prettify → decode → source, dir, event, command fields match
```

## Steps

1. Set `req.LogEntry` with `command.executed` and full `command` struct.
2. Call `logs_viewer_prettify_entry` via Swift test helper.
3. Assert decodes to equivalent field values.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsViewerPrettifyEntry
	req.LogEntry = &NotifyLogEntry{
		Source:    "log",
		Timestamp: "2026-06-23T12:00:00Z",
		Dir:       "/Users/me/proj/my-app",
		Event:     "command.executed",
		Command: &CommandLogDetails{
			Command:    "/usr/local/bin/code /Users/me/proj/my-app",
			ExitCode:   0,
			Stdout:     "ok",
			Stderr:     "",
			DurationMs: 99,
		},
	}
	return nil
}
```
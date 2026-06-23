# Scenario

**Feature**: non-`command.executed` entries produce no command detail lines

```
# ordinary stop event without command field
event=stop → detail_lines empty
```

## Steps

1. Set `req.LogEntry` with `event: "stop"` and no `command` struct.
2. Call `logs_viewer_format_command_details` via Swift test helper.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsViewerFormatCommandDetails
	req.LogEntry = &NotifyLogEntry{
		Source:    "pi",
		Timestamp: "2026-06-23T12:00:00Z",
		Dir:       "/Users/me/proj/my-app",
		Event:     "stop",
	}
	return nil
}
```
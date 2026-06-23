# Scenario

**Feature**: format log entry display line for viewer list row

```
# entry with full dir path
{"source":"pi","timestamp":"2026-06-23T12:00:00Z","dir":"/Users/me/proj/my-app","event":"stop"}

# formatted display line includes timestamp, source, basename "my-app"
```

## Steps

1. Set `req.LogEntry` with known timestamp, source, and dir.
2. Call `logs_viewer_format_entry` via Swift test helper.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsViewerFormatEntry
	req.LogEntry = &NotifyLogEntry{
		Source:    "pi",
		Timestamp: "2026-06-23T12:00:00Z",
		Dir:       "/Users/me/proj/my-app",
		Event:     "stop",
	}
	return nil
}
```
# Scenario

**Feature**: prettify log entry as indented JSON for raw JSON sheet

```
# standard notify entry
→ pretty_json with newlines, 2-space indent, "source" and "dir" keys
```

## Steps

1. Set `req.LogEntry` with known `source`, `dir`, `timestamp`, and `event`.
2. Call `logs_viewer_prettify_entry` via Swift test helper.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsViewerPrettifyEntry
	req.LogEntry = &NotifyLogEntry{
		Source:    "pi",
		Timestamp: "2026-06-23T12:00:00Z",
		Dir:       "/Users/me/proj/my-app",
		Event:     "stop",
	}
	return nil
}
```
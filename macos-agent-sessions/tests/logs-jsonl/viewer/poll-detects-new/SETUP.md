# Scenario

**Feature**: viewer poll detects entry count increase

```
# simulate two poll cycles (no wall-clock wait)
poll 1: GET /api/logs -> 1 entry
poll 2: GET /api/logs -> 2 entries (new log appended)
```

## Steps

1. Set `req.PollSequence` with 1 entry then 2 entries.
2. Call `logs_viewer_poll_detects_new` via Swift test helper.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionLogsViewerPollDetectsNew
	req.PollSequence = []PollStep{
		{Entries: []NotifyLogEntry{
			{Source: "notify", Timestamp: "2026-06-23T10:00:00Z", Dir: "/proj-a", Event: "start"},
		}},
		{Entries: []NotifyLogEntry{
			{Source: "notify", Timestamp: "2026-06-23T10:00:00Z", Dir: "/proj-a", Event: "start"},
			{Source: "pi", Timestamp: "2026-06-23T10:01:00Z", Dir: "/proj-b", Event: "stop"},
		}},
	}
	return nil
}
```
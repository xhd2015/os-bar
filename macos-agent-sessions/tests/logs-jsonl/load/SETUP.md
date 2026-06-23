# Scenario

**Feature**: daemon loads existing JSONL file on startup

```
# seed notify-logs.jsonl before serve
stateDir/notify-logs.jsonl (3 lines) -> start daemon -> loadLogs

# API returns all seeded entries
harness <- GET /api/logs -> len=3
```

## Preconditions

- Seed file is written **before** daemon start (no running process yet).
- Each seed line is a complete `NotifyLogEntry` JSON object.

## Steps

1. Create `stateDir` and write `notify-logs.jsonl` with N lines.
2. Start daemon via `http_sequence` ending with `GET /api/logs`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	return nil
}
```
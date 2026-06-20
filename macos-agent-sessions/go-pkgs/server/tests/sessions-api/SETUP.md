# Scenario

**Feature**: HTTP API parity with former Swift SessionServer

```
# notify pushes session events or log-only entries
CLI/harness -> POST /api/notify -> daemon -> events.json | notify-logs.json

# list/info/logs/events endpoints serve stored state
harness <- GET /api/list | /api/logs | DELETE /api/events
```

## Preconditions

- Daemon implements existing Swift-server endpoints plus standard HTTP error codes.
- Invalid JSON → 400; missing `dir` → 400; unknown path → 404; wrong method → 405.

## Steps

1. Set `req.Action = http_sequence` or `http_request`.
2. `req.Port = 0` for ephemeral binding.
3. Leaf `Setup` configures HTTP method, path, and body.

## Context

- `source=="notify"` on POST `/api/notify` creates a session event.
- Absent or other `source` values are log-only (no session event).

```go
func Setup(t *testing.T, req *Request) error {
	req.Port = 0
	return nil
}
```
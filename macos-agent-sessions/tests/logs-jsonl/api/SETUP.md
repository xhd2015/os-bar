# Scenario

**Feature**: `GET /api/logs` HTTP response remains JSON array

```
# append via notify, then fetch logs
harness -> POST /api/notify -> notify-logs.jsonl on disk
harness <- GET /api/logs -> JSON array body (not JSONL text)
```

## Preconditions

- On-disk format is JSONL; wire format is JSON array for API compatibility.

## Steps

1. POST log-only notify.
2. GET `/api/logs`.
3. Assert response body parses as JSON array.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	return nil
}
```
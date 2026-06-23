# Scenario

**Feature**: legacy `notify-logs.json` JSON array migrates to JSONL on daemon load

```
# seed legacy array file only
stateDir/notify-logs.json -> [{...},{...}]

# daemon start triggers loadLogs migration
-> notify-logs.jsonl created, notify-logs.json removed
```

## Preconditions

- Migration runs on first `loadLogs` when `.jsonl` absent and `.json` present.
- No `.bak` file; legacy `.json` deleted after successful conversion.

## Steps

1. Write `notify-logs.json` as JSON array **before** daemon start.
2. Start daemon (implicit in `http_sequence`).
3. Assert disk state and optional `GET /api/logs`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	return nil
}
```
# Scenario

**Feature**: daemon prunes events older than 7 days on load

```
# events.json seeded with 8-day-old event before start
harness -> write events.json (stale) -> stateDir

# daemon load prunes stale entries
harness -> serve -> daemon (prune on load)
harness <- GET /api/list -> []
```

## Steps

1. Set `req.SeedEvents = "stale-event.json"` (8 days old).
2. Start daemon (prune runs on load).
3. GET `/api/list`.

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedEvents = "stale-event.json"
	req.Action = actionHTTPRequest
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/list"
	return nil
}
```
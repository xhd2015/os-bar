# Scenario

**Feature**: no daemon on port → info request fails

```
# pick ephemeral port, do NOT start serve
harness -> (no daemon on 127.0.0.1:<port>)

# connection refused or similar
harness <- GET /api/info -> error, storage_path empty
```

## Steps

1. Set `req.Action = daemon_info_unreachable`.
2. Assign ephemeral port via `req.Port = 0` (no `serve` subprocess).
3. Attempt `GET /api/info`.

## Context

- Mirrors menu-bar / Help menu state when daemon is down.
- App must not fall back to local paths; error propagates to menu label logic.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonInfoUnreachable
	req.Port = 0
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/info"
	return nil
}
```
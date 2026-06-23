# Scenario

**Feature**: daemon `GET /api/info` resolves `storage_path` for Open Logs

```
# success: serve with temp --state-dir
harness -> serve (isolated state) -> daemon
harness <- GET /api/info -> {"storage_path":"<stateDir>", ...}

# unreachable: ephemeral port, no process listening
harness <- GET /api/info -> connection refused
```

## Preconditions

- Daemon binds `127.0.0.1` only with `--port` and `--state-dir`.
- `storage_path` in the JSON body equals the daemon's `--state-dir` argument.
- Unreachable tests must **not** start `serve`.

## Steps

1. Set `req.Port = 0` for ephemeral binding (success leaves only).
2. Leaf `Setup` sets `req.Action` to `daemon_info` or `daemon_info_unreachable`.
3. Success leaves use `GET /api/info`; unreachable leaves expect a connection error.

## Context

- This is the **only** path-resolution source for Open Logs (no local/env fallback).
- `event_count` and `port` are returned but not asserted in v1 tests.

```go
func Setup(t *testing.T, req *Request) error {
	req.Port = 0
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/info"
	return nil
}
```
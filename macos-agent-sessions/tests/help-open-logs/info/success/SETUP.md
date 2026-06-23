# Scenario

**Feature**: running daemon returns `storage_path` matching isolated state dir

```
# start daemon with temp state dir
harness -> serve --state-dir <tmp>/state -> daemon

# info echoes storage_path
harness <- GET /api/info -> storage_path == <tmp>/state
```

## Steps

1. Set `req.Action = daemon_info`.
2. `GET /api/info` on the running daemon (implicit start in `Run`).

## Context

- Represents the happy path before Open Logs can resolve the log file location.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonInfo
	req.HTTPMethod = "GET"
	req.HTTPPath = "/api/info"
	return nil
}
```
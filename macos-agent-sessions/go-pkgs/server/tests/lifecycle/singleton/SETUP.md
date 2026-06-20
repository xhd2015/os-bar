# Scenario

**Feature**: singleton guard prevents duplicate daemon listeners

```
# first serve owns port and PID file
doctest -> serve -> daemon (pid=N)

# second serve detects live peer and exits 0
doctest -> serve (again) -> exit 0
doctest <- GET /api/health -> still ok
```

## Steps

1. Set `req.Action = daemon_singleton`.
2. `Run` starts daemon, runs second `serve` with same `--state-dir` and `--port`.

## Context

- Second start must exit 0 without spawning a competing listener.
- Health check on the original daemon must still succeed.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonSingleton
	return nil
}
```
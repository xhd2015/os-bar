# Scenario

**Feature**: daemon process lifecycle — health probe and singleton guard

```
# first serve binds port and writes daemon.pid
doctest -> serve --state-dir --port -> daemon (PID file)

# health confirms readiness; second serve is no-op when PID alive
doctest <- GET /api/health -> {"ok":true}
doctest -> serve (again) -> exit 0 (singleton)
```

## Preconditions

- Daemon must implement `GET /api/health` returning `{"ok":true}` when ready.
- Singleton: if `daemon.pid` points to a live process with healthy endpoint, second `serve` exits 0.

## Steps

1. Set `req.Port = 0` for ephemeral binding.
2. Lifecycle leaves use `start_daemon`, `http_request`, or `daemon_singleton` actions.

## Context

- Never use production port `38271` in tests.
- `t.Cleanup` stops the daemon subprocess after each leaf.

```go
func Setup(t *testing.T, req *Request) error {
	req.Port = 0
	return nil
}
```
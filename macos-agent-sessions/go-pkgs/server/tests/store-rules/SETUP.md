# Scenario

**Feature**: session store rules enforced via HTTP (parity with SessionStore.swift)

```
# notify writes events; store applies dedup, cap, consume, prune
harness -> POST /api/notify -> daemon -> events.json (dedup, cap 20, sort)

# consume and prune-on-load mutate persisted state
harness -> POST /api/events/consume -> events.json
daemon load -> prune events older than 7 days
```

## Preconditions

- Dedup by `dir`: re-notify bumps `timestamp`, sets `consumed=false`.
- Cap: 20 events max (evict oldest).
- Prune on load: drop events older than 7 days.
- Sort: newest `timestamp` first.

## Steps

1. Set `req.Action = http_sequence` for multi-step store tests.
2. `prune-on-load` sets `req.SeedEvents` before daemon start.

## Context

- Store state persists in `stateDir/events.json`.
- `POST /api/events/consume` replaces Swift `markConsumed`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Port = 0
	return nil
}
```
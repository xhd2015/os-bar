# Scenario

**Feature**: SessionStore operations (add, dedup, prune, cap, sort, consumed)

```
doctest -> add_event | prune | mark_consumed -> SessionStore -> events
```

## Preconditions
- All tests in this subtree exercise `SessionStore` operations directly (no HTTP server involved).
- The test helper creates a fresh `SessionStore` instance for each action unless `events_json` is provided to preload state.

## Steps
- This is a grouping node. Specific steps are defined in each leaf.

## Context
- Store actions: `"add_event"`, `"add_events_batch"`, `"prune"`, `"relative_time"`.
- `events_json` preloads UserDefaults with a JSON array of `SessionEvent` objects before the action runs.
- `dirs` (array) is used by `"add_events_batch"` to add multiple events in sequence.

```go
func Setup(t *testing.T, req *Request) error {
	// All store leaves operate on SessionStore.
	// Each leaf sets its specific action and parameters.
	t.Logf("store: preparing SessionStore test")
	return nil
}
```

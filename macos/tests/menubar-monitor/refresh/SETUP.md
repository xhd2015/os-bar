## Preconditions
- A mock host-info fetcher is configured to return different metric values after each timer tick.
  - Tick 0 (initial): CPU = 45.2%, MEM = 72.8%
  - Tick 1: CPU = 52.3%, MEM = 68.1%
  - Tick 2+: CPU = 38.7%, MEM = 75.4%
- The action under test is `"wait_tick"` — wait for the next timer tick, then take a snapshot.

## Steps
- This is a grouping node. Specific steps are defined in the `updates-on-tick` leaf.

## Context
- All tests in this subtree validate that the `SystemMonitor` timer fires and refreshes metric values.
- A `wait_tick` action should produce a snapshot that reflects updated values from the mock fetcher.
- The test mode timer fires on demand (fast-forward) rather than waiting 10 real seconds.

```go
func Setup(t *testing.T, req *Request) error {
	// All refresh leaves use the "wait_tick" action
	req.Action = "wait_tick"
	return nil
}
```

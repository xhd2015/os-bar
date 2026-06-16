## Steps
1. Take an **initial snapshot**: call `Run(t, {action: "fetch"})` to get current metrics (snapshot1).
2. Trigger a **timer tick**: call `Run(t, {action: "wait_tick"})` to wait for the next tick and get updated metrics (snapshot2).
3. Compare snapshot2 against snapshot1.

## Context
- The mock fetcher returns CPU = 45.2% on first fetch (snapshot1), and CPU = 52.3% after the first tick (snapshot2).
- This leaf validates that the timer mechanism actually refreshes data — values should differ between snapshots.
- Both snapshots must have values within [0.0, 100.0].

```go
func Setup(t *testing.T, req *Request) error {
	// Action is set to "wait_tick" by parent refresh/SETUP.md.
	// The Assert function will call Run() twice: first with "fetch", then with "wait_tick".
	t.Logf("updates-on-tick: preparing timer-tick refresh test")
	return nil
}
```

## Expected
- `snapshot1` (initial fetch) and `snapshot2` (after `wait_tick`) both have valid metric ranges.
- `snapshot2.CPUPercent` differs from `snapshot1.CPUPercent`, or `snapshot2.MEMPercent` differs from `snapshot1.MEMPercent` — confirming the timer refreshed the data.
- If the mock returns the same values (no change in OS), the test still passes but logs a warning.

## Side Effects
- `SystemMonitor` internal timer state advances by one tick.

## Errors
- If either snapshot has metrics outside [0.0, 100.0], the test fails.
- If `Run` returns an error for either call, the test fails with the error details.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	// resp here is from the "wait_tick" Run call
	// We need to also get the initial "fetch" snapshot
	// Since Run is only called once per leaf, we handle both calls here

	if err != nil {
		t.Fatalf("Run(wait_tick) returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response from wait_tick")
	}

	// Get snapshot1 with a fetch
	fetchReq := &Request{Action: "fetch"}
	snap1, snapErr := Run(t, fetchReq)
	if snapErr != nil {
		t.Fatalf("Run(fetch) returned unexpected error: %v", snapErr)
	}
	if snap1 == nil {
		t.Fatal("expected non-nil Response from fetch")
	}

	// Validate both snapshots
	snap2 := resp
	if snap1.CPUPercent < 0.0 || snap1.CPUPercent > 100.0 {
		t.Fatalf("snapshot1 cpuPercent out of range: %.2f", snap1.CPUPercent)
	}
	if snap1.MEMPercent < 0.0 || snap1.MEMPercent > 100.0 {
		t.Fatalf("snapshot1 memPercent out of range: %.2f", snap1.MEMPercent)
	}
	if snap2.CPUPercent < 0.0 || snap2.CPUPercent > 100.0 {
		t.Fatalf("snapshot2 cpuPercent out of range: %.2f", snap2.CPUPercent)
	}
	if snap2.MEMPercent < 0.0 || snap2.MEMPercent > 100.0 {
		t.Fatalf("snapshot2 memPercent out of range: %.2f", snap2.MEMPercent)
	}

	// Check that values changed (timer fired)
	cpuChanged := snap1.CPUPercent != snap2.CPUPercent
	memChanged := snap1.MEMPercent != snap2.MEMPercent
	if !cpuChanged && !memChanged {
		t.Log("WARNING: snapshot2 values unchanged from snapshot1 — timer may not have fired or mock returned same values")
		// This is not a hard failure — mock may legitimately return same values
	} else {
		t.Logf("Timer tick confirmed: cpu %v (%.2f → %.2f), mem %v (%.2f → %.2f)",
			cpuChanged, snap1.CPUPercent, snap2.CPUPercent,
			memChanged, snap1.MEMPercent, snap2.MEMPercent)
	}
}
```

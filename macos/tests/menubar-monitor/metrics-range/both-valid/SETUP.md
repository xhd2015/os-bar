# Scenario

**Feature**: fetch snapshot — both CPU and MEM valid

## Steps
1. Call `Run(t, req)` with `action: "fetch"` to obtain a snapshot.
2. Capture the `Response` with both `cpuPercent` and `memPercent`.

## Context
- This leaf validates that **both** CPU and MEM metrics are simultaneously present and within valid range in a single `Response`.
- This ensures the `SystemMonitor` returns complete data (no missing fields, no NaN values).

```go
func Setup(t *testing.T, req *Request) error {
	// Action is set to "fetch" by parent metrics-range/SETUP.md
	t.Logf("both-valid: requesting fetch snapshot to validate both metrics simultaneously")
	return nil
}
```

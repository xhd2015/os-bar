# Scenario

**Feature**: fetch snapshot — CPU in [0, 100]

## Steps
1. Call `Run(t, req)` with `action: "fetch"` to obtain an immediate CPU + MEM snapshot.
2. Capture the `Response` containing `cpuPercent` and `memPercent`.

## Context
- This leaf validates that `cpuPercent` is a valid `Double` within the expected range.
- The mock fetcher returns CPU = 45.2% on the initial fetch.

```go
func Setup(t *testing.T, req *Request) error {
	// Action is set to "fetch" by parent metrics-range/SETUP.md
	t.Logf("cpu-in-range: requesting fetch snapshot to validate CPU metric")
	return nil
}
```

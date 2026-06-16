## Steps
1. Call `Run(t, req)` with `action: "fetch"` to obtain an immediate CPU + MEM snapshot.
2. Capture the `Response` containing `cpuPercent` and `memPercent`.

## Context
- This leaf validates that `memPercent` is a valid `Double` within the expected range.
- The mock fetcher returns MEM = 72.8% on the initial fetch.

```go
func Setup(t *testing.T, req *Request) error {
	// Action is set to "fetch" by parent metrics-range/SETUP.md
	t.Logf("mem-in-range: requesting fetch snapshot to validate MEM metric")
	return nil
}
```

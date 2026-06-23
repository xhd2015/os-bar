# Scenario

**Feature**: immediate fetch snapshot — CPU and MEM range validation

## Preconditions
- A mock host-info fetcher is injected into `SystemMonitor` that returns known, deterministic values.
- The action under test is `"fetch"` — an immediate snapshot without waiting for any timer tick.

## Steps
- This is a grouping node. Specific steps are defined in each leaf.

## Context
- All tests in this subtree validate that metrics returned by `Run(t, {action:"fetch"})` fall within valid ranges.
- `cpuPercent ∈ [0.0, 100.0]` and `memPercent ∈ [0.0, 100.0]`.
- Values outside this range indicate a bug in the metric calculation or data fetching logic.

```go
func Setup(t *testing.T, req *Request) error {
	// All metrics-range leaves use the "fetch" action
	req.Action = "fetch"
	return nil
}
```

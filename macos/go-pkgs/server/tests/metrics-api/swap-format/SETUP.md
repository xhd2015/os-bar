# Scenario

**Feature**: swap byte values formatted as human-readable binary labels

```
# FormatBytes converts raw bytes to integer unit labels
doctest -> monitor.FormatBytes(bytes) -> "2GB" | "100MB" | "0B"

# FormatSwapDisplay composes total then used for dropdown line
doctest -> monitor.FormatSwapDisplay(total, used) -> "5%(100MB/2GB)"
```

## Preconditions

- `monitor.FormatBytes` and `monitor.FormatSwapDisplay` exist in `go-pkgs/monitor`.
- Binary (1024) units; integer labels only; no decimal fractions.

## Steps

1. Format leaves set `req.Action` to `format_bytes` or `format_swap_display`.
2. Input values set via `FormatBytesInput` or `FormatSwapTotal`/`FormatSwapUsed`.
3. `Run` stores formatted string in `resp.FormatResult` (no daemon subprocess).

## Context

- Mirrors Swift dropdown display rules: `Swap: 89%(8GB/9GB)`.
- When total is 0, UI shows `0B 0B` (tested via `swap-format-zero` and display leaf).

```go
func Setup(t *testing.T, req *Request) error {
	// Format leaves call monitor helpers directly; no mock daemon required.
	req.MockMetrics = false
	return nil
}
```
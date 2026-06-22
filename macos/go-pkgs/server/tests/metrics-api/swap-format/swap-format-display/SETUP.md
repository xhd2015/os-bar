# Scenario

**Feature**: FormatSwapDisplay composes total and used labels for dropdown line

```
# mock tick 0 swap values
doctest -> monitor.FormatSwapDisplay(2147483648, 104857600) -> "5% (100MB/2GB)"
```

## Steps

1. Set `req.Action = format_swap_display`.
2. Set `req.FormatSwapTotal = 2147483648`, `req.FormatSwapUsed = 104857600`.

## Context

- Matches Swift dropdown: `Swap: 5% (100MB/2GB)` (rounded percent, used/total).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatSwapDisplay
	req.FormatSwapTotal = 2147483648
	req.FormatSwapUsed = 104857600
	return nil
}
```
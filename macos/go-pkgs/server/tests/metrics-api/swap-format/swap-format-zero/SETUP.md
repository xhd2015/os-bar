# Scenario

**Feature**: FormatBytes formats zero bytes as "0B"

```
# no swap configured
doctest -> monitor.FormatBytes(0) -> "0B"
```

## Steps

1. Set `req.Action = format_bytes`.
2. Set `req.FormatBytesInput = 0`.

## Context

- When `swap_total_bytes == 0`, UI displays `Swap: 0B 0B`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatBytes
	req.FormatBytesInput = 0
	return nil
}
```
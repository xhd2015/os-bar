# Scenario

**Feature**: FormatDiskBytes formats zero disk bytes as "0B"

```
# zero bytes
doctest -> monitor.FormatDiskBytes(0) -> "0B"
```

## Steps

1. Set `req.Action = format_disk_bytes`.
2. Set `req.FormatBytesInput = 0`.

## Context

- Shared zero semantics with swap-format-zero; disk uses `FormatDiskBytes`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatDiskBytes
	req.FormatBytesInput = 0
	return nil
}
```
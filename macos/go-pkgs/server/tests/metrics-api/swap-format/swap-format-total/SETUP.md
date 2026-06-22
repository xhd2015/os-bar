# Scenario

**Feature**: FormatBytes formats 2 GiB total swap as integer GB label

```
# 2147483648 bytes = 2 GiB
doctest -> monitor.FormatBytes(2147483648) -> "2GB"
```

## Steps

1. Set `req.Action = format_bytes`.
2. Set `req.FormatBytesInput = 2147483648`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatBytes
	req.FormatBytesInput = 2147483648
	return nil
}
```
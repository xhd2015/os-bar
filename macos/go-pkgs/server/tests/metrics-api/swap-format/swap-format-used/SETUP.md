# Scenario

**Feature**: FormatBytes formats 100 MiB used swap as integer MB label

```
# 104857600 bytes = 100 MiB
doctest -> monitor.FormatBytes(104857600) -> "100MB"
```

## Steps

1. Set `req.Action = format_bytes`.
2. Set `req.FormatBytesInput = 104857600`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatBytes
	req.FormatBytesInput = 104857600
	return nil
}
```
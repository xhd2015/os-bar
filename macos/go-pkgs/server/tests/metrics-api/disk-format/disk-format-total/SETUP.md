# Scenario

**Feature**: FormatDiskBytesBinaryTotal formats 500 GiB total disk as integer 1024-based GB label

```
# 536870912000 bytes = 500 GiB
doctest -> monitor.FormatDiskBytesBinaryTotal(536870912000) -> "500GB"
```

## Steps

1. Set `req.Action = format_disk_bytes_binary_total`.
2. Set `req.FormatBytesInput = 536870912000`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatDiskBytesBinaryTotal
	req.FormatBytesInput = 536870912000
	return nil
}
```
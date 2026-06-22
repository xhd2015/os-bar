# Scenario

**Feature**: FormatDiskBytesBinaryUsed formats 200 GiB used disk as 1024-based GB label with two decimals

```
# 214748364800 bytes = 200.00 GiB
doctest -> monitor.FormatDiskBytesBinaryUsed(214748364800) -> "200.00GB"
```

## Steps

1. Set `req.Action = format_disk_bytes_binary_used`.
2. Set `req.FormatBytesInput = 214748364800`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionFormatDiskBytesBinaryUsed
	req.FormatBytesInput = 214748364800
	return nil
}
```
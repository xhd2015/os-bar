## Expected

- `resp.HTTPStatus == 200`.
- `resp.DiskUsedBytes <= resp.DiskTotalBytes`.
- Both values are non-negative (`uint64`).

## Errors

- `disk_used_bytes > disk_total_bytes` fails the test with both values logged.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/metrics, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.DiskUsedBytes > resp.DiskTotalBytes {
		t.Fatalf("disk_used_bytes (%d) must be <= disk_total_bytes (%d)",
			resp.DiskUsedBytes, resp.DiskTotalBytes)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("disk-bytes-valid OK: used=%d total=%d", resp.DiskUsedBytes, resp.DiskTotalBytes)
}
```
## Expected

- `resp.HTTPStatus == 200`.
- `resp.SwapUsedBytes <= resp.SwapTotalBytes`.
- Both values are non-negative (`uint64`).

## Errors

- `swap_used_bytes > swap_total_bytes` fails the test with both values logged.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/metrics, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.SwapUsedBytes > resp.SwapTotalBytes {
		t.Fatalf("swap_used_bytes (%d) must be <= swap_total_bytes (%d)",
			resp.SwapUsedBytes, resp.SwapTotalBytes)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("swap-bytes-valid OK: used=%d total=%d", resp.SwapUsedBytes, resp.SwapTotalBytes)
}
```
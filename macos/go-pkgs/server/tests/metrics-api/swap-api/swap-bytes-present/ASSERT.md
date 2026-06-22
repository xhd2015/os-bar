## Expected

- `resp.HTTPStatus == 200`.
- `resp.SwapTotalBytes == 2147483648` (mock tick 0, 2 GiB).
- `resp.SwapUsedBytes == 104857600` (mock tick 0, 100 MiB).
- Raw JSON body contains `swap_total_bytes` and `swap_used_bytes` keys.

## Errors

- Missing or zero swap fields when mock tick 0 expects non-zero total fails the test.
- Non-200 HTTP status fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/metrics, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	const wantTotal = uint64(2147483648)
	const wantUsed = uint64(104857600)
	if resp.SwapTotalBytes != wantTotal {
		t.Fatalf("swap_total_bytes: got %d, want %d", resp.SwapTotalBytes, wantTotal)
	}
	if resp.SwapUsedBytes != wantUsed {
		t.Fatalf("swap_used_bytes: got %d, want %d", resp.SwapUsedBytes, wantUsed)
	}
	if !strings.Contains(resp.HTTPBody, "swap_total_bytes") || !strings.Contains(resp.HTTPBody, "swap_used_bytes") {
		t.Fatalf("expected swap fields in JSON body, got %q", resp.HTTPBody)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("swap-bytes-present OK: total=%d used=%d", resp.SwapTotalBytes, resp.SwapUsedBytes)
}
```
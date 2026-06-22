## Expected

- `resp.HTTPStatus == 200`.
- `resp.DiskTotalBytes == 536870912000` (mock tick 0, 500 GiB).
- `resp.DiskUsedBytes == 214748364800` (mock tick 0, 200 GiB).
- Raw JSON body contains `disk_total_bytes` and `disk_used_bytes` keys.

## Errors

- Missing or zero disk fields when mock tick 0 expects non-zero total fails the test.
- Non-200 HTTP status fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/metrics, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	const wantTotal = uint64(536870912000)
	const wantUsed = uint64(214748364800)
	if resp.DiskTotalBytes != wantTotal {
		t.Fatalf("disk_total_bytes: got %d, want %d", resp.DiskTotalBytes, wantTotal)
	}
	if resp.DiskUsedBytes != wantUsed {
		t.Fatalf("disk_used_bytes: got %d, want %d", resp.DiskUsedBytes, wantUsed)
	}
	if !strings.Contains(resp.HTTPBody, "disk_total_bytes") || !strings.Contains(resp.HTTPBody, "disk_used_bytes") {
		t.Fatalf("expected disk fields in JSON body, got %q", resp.HTTPBody)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("disk-bytes-present OK: total=%d used=%d", resp.DiskTotalBytes, resp.DiskUsedBytes)
}
```
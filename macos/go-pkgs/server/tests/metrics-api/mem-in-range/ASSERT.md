## Expected

- `resp.HTTPStatus == 200`.
- `resp.MEMPercent` is a valid `float64`.
- `resp.MEMPercent ∈ [0.0, 100.0]`.
- Mock tick 0: log `mem_percent = 72.8` when value matches (parity with Swift mock).

## Errors

- If `resp.MEMPercent < 0.0`, fail with MEM below valid minimum.
- If `resp.MEMPercent > 100.0`, fail with MEM exceeds valid maximum.
- Non-200 HTTP status fails the test.

## Side Effects

- No persistent metrics history written to disk.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/metrics, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.MEMPercent < 0.0 {
		t.Fatalf("mem_percent must be >= 0.0, got %.2f", resp.MEMPercent)
	}
	if resp.MEMPercent > 100.0 {
		t.Fatalf("mem_percent must be <= 100.0, got %.2f", resp.MEMPercent)
	}
	if resp.MEMPercent == 72.8 {
		t.Logf("mock tick 0 mem_percent = 72.8 (parity with Swift MockSystemInfoProvider)")
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("mem-in-range OK: mem_percent=%.2f", resp.MEMPercent)
}
```
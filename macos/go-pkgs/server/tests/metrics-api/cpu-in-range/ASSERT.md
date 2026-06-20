## Expected

- `resp.HTTPStatus == 200`.
- `resp.CPUPercent` is a valid `float64`.
- `resp.CPUPercent ∈ [0.0, 100.0]`.
- Mock tick 0: log `cpu_percent = 45.2` when value matches (parity with Swift mock).

## Errors

- If `resp.CPUPercent < 0.0`, fail with CPU below valid minimum.
- If `resp.CPUPercent > 100.0`, fail with CPU exceeds valid maximum.
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
	if resp.CPUPercent < 0.0 {
		t.Fatalf("cpu_percent must be >= 0.0, got %.2f", resp.CPUPercent)
	}
	if resp.CPUPercent > 100.0 {
		t.Fatalf("cpu_percent must be <= 100.0, got %.2f", resp.CPUPercent)
	}
	if resp.CPUPercent == 45.2 {
		t.Logf("mock tick 0 cpu_percent = 45.2 (parity with Swift MockSystemInfoProvider)")
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("cpu-in-range OK: cpu_percent=%.2f", resp.CPUPercent)
}
```
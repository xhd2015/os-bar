## Expected

- `resp.HTTPStatus == 200`.
- `resp.CPUPercent ∈ [0.0, 100.0]` and `resp.MEMPercent ∈ [0.0, 100.0]`.
- Both metrics are non-zero in mock mode (tick 0: 45.2 and 72.8).

## Errors

- Either metric outside `[0.0, 100.0]` fails the test with the offending value.
- Zero values in mock mode fail the test (mock tick 0 is non-zero).

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from /api/metrics, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.CPUPercent < 0.0 || resp.CPUPercent > 100.0 {
		t.Fatalf("cpu_percent out of range: got %.2f, want [0.0, 100.0]", resp.CPUPercent)
	}
	if resp.MEMPercent < 0.0 || resp.MEMPercent > 100.0 {
		t.Fatalf("mem_percent out of range: got %.2f, want [0.0, 100.0]", resp.MEMPercent)
	}
	if resp.CPUPercent == 0.0 {
		t.Fatal("expected non-zero cpu_percent in mock mode")
	}
	if resp.MEMPercent == 0.0 {
		t.Fatal("expected non-zero mem_percent in mock mode")
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("both-valid OK: cpu=%.2f mem=%.2f", resp.CPUPercent, resp.MEMPercent)
}
```
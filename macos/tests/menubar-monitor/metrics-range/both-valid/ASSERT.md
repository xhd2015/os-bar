## Expected
- `resp.CPUPercent` and `resp.MEMPercent` are both present (non-zero values from mock).
- `resp.CPUPercent ∈ [0.0, 100.0]` and `resp.MEMPercent ∈ [0.0, 100.0]`.

## Errors
- If either metric is outside [0.0, 100.0], the test fails with the specific metric and value.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}

	// CPU
	if resp.CPUPercent < 0.0 || resp.CPUPercent > 100.0 {
		t.Fatalf("cpuPercent out of range: got %.2f, want [0.0, 100.0]", resp.CPUPercent)
	}

	// MEM
	if resp.MEMPercent < 0.0 || resp.MEMPercent > 100.0 {
		t.Fatalf("memPercent out of range: got %.2f, want [0.0, 100.0]", resp.MEMPercent)
	}

	t.Logf("cpuPercent = %.2f, memPercent = %.2f — both in valid range", resp.CPUPercent, resp.MEMPercent)
}
```

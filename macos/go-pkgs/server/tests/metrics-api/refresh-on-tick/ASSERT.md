## Expected

- Initial snapshot (tick 0): CPU=45.2, MEM=72.8.
- After `POST /api/test/advance-tick` (tick 1): CPU=52.3, MEM=68.1.
- At least one metric differs between before and after snapshots.
- All four values ∈ `[0.0, 100.0]`.

## Side Effects

- Mock provider internal tick counter advances by one.

## Errors

- If advance-tick fails or metrics unchanged, test fails.
- Values outside valid range fail the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from final /api/metrics, got %d", resp.HTTPStatus)
	}

	tick := parseMetricsTickResult(t, resp.HTTPBody)

	for label, v := range map[string]float64{
		"before_cpu": tick.BeforeCPU,
		"before_mem": tick.BeforeMEM,
		"after_cpu":  tick.AfterCPU,
		"after_mem":  tick.AfterMEM,
	} {
		if v < 0.0 || v > 100.0 {
			t.Fatalf("%s out of range: %.2f", label, v)
		}
	}

	if tick.BeforeCPU != 45.2 {
		t.Fatalf("expected before_cpu=45.2 (mock tick 0), got %.2f", tick.BeforeCPU)
	}
	if tick.BeforeMEM != 72.8 {
		t.Fatalf("expected before_mem=72.8 (mock tick 0), got %.2f", tick.BeforeMEM)
	}
	if tick.AfterCPU != 52.3 {
		t.Fatalf("expected after_cpu=52.3 (mock tick 1), got %.2f", tick.AfterCPU)
	}
	if tick.AfterMEM != 68.1 {
		t.Fatalf("expected after_mem=68.1 (mock tick 1), got %.2f", tick.AfterMEM)
	}

	cpuChanged := tick.BeforeCPU != tick.AfterCPU
	memChanged := tick.BeforeMEM != tick.AfterMEM
	if !cpuChanged && !memChanged {
		t.Fatal("expected at least one metric to change after advance-tick")
	}

	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("refresh-on-tick OK: cpu %.2f→%.2f, mem %.2f→%.2f",
		tick.BeforeCPU, tick.AfterCPU, tick.BeforeMEM, tick.AfterMEM)
}
```
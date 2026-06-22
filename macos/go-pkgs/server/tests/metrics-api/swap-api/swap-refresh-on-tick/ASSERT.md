## Expected

- Before (tick 0): `swap_total=2147483648`, `swap_used=104857600`.
- After (tick 1): `swap_total=2147483648`, `swap_used=157286400`.
- Swap used changes; swap total unchanged between tick 0 and tick 1.

## Side Effects

- Mock provider internal tick counter advances by one.

## Errors

- Unchanged swap used after advance-tick fails the test.
- Total changing between tick 0 and tick 1 fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200 from final /api/metrics, got %d", resp.HTTPStatus)
	}

	tick := parseMetricsTickResult(t, resp.HTTPBody)

	const wantTotal = uint64(2147483648)
	const wantUsedBefore = uint64(104857600)
	const wantUsedAfter = uint64(157286400)

	if tick.BeforeSwapTotal != wantTotal {
		t.Fatalf("before_swap_total: got %d, want %d", tick.BeforeSwapTotal, wantTotal)
	}
	if tick.AfterSwapTotal != wantTotal {
		t.Fatalf("after_swap_total: got %d, want %d", tick.AfterSwapTotal, wantTotal)
	}
	if tick.BeforeSwapUsed != wantUsedBefore {
		t.Fatalf("before_swap_used: got %d, want %d", tick.BeforeSwapUsed, wantUsedBefore)
	}
	if tick.AfterSwapUsed != wantUsedAfter {
		t.Fatalf("after_swap_used: got %d, want %d", tick.AfterSwapUsed, wantUsedAfter)
	}
	if tick.BeforeSwapUsed == tick.AfterSwapUsed {
		t.Fatal("expected swap_used_bytes to change after advance-tick")
	}
	if tick.BeforeSwapTotal != tick.AfterSwapTotal {
		t.Fatalf("expected swap_total_bytes to stay constant: before=%d after=%d",
			tick.BeforeSwapTotal, tick.AfterSwapTotal)
	}
	if tick.AfterSwapUsed > tick.AfterSwapTotal {
		t.Fatalf("after tick: swap_used (%d) > swap_total (%d)", tick.AfterSwapUsed, tick.AfterSwapTotal)
	}

	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("swap-refresh-on-tick OK: used %d→%d, total=%d",
		tick.BeforeSwapUsed, tick.AfterSwapUsed, tick.AfterSwapTotal)
}
```
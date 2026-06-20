## Expected

- `resp.SecondStartExitCode == 0`.
- `resp.PID > 0` (first daemon PID recorded).
- `resp.HTTPStatus == 200` (health or list fallback still works).
- `resp.BaseURL` is non-empty.

## Side Effects

- Only one `daemon.pid` under isolated `resp.StateDir`.
- No second listener on the same port.

## Errors

- Second `serve` exiting non-zero fails the test.
- Health/list probe failing after second start fails the test.

## Exit Code

- Second `serve` invocation: `0`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.SecondStartExitCode != 0 {
		t.Fatalf("expected second serve exit 0, got %d", resp.SecondStartExitCode)
	}
	if resp.PID <= 0 {
		t.Fatalf("expected positive first daemon PID, got %d", resp.PID)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected health OK after singleton, got status %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.BaseURL == "" {
		t.Fatal("expected non-empty BaseURL")
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Logf("lifecycle/singleton OK: pid=%d secondExit=%d", resp.PID, resp.SecondStartExitCode)
}
```
## Expected
- `resp.WindowOpen == true`.
- `resp.WindowMain == true` (AX `AXMain` on Integrations window).
- `resp.AppFrontmost == true` (test app is frontmost).
- `resp.Error == ""`.

## Side Effects
- Integrations window remains open after obscure + second click.

## Errors
- If window is not main/frontmost after second Settings… click, test fails.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.WindowOpen != true {
		t.Fatal("expected window_open=true after second Settings… click")
	}
	if !resp.WindowMain {
		t.Fatal("expected window_main=true (AXMain on Integrations window)")
	}
	if !resp.AppFrontmost {
		t.Fatal("expected app_frontmost=true after second Settings… click")
	}
	t.Logf("settings-menu/click-brings-to-front OK")
}
```
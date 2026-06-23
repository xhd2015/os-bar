## Expected

- `resp.Error == ""`.
- `resp.MenuLabel == "Logs"`.
- `resp.MenuEnabled == true` (even with non-empty `info_error`).

## Side Effects

- No UI automation; only pure viewer menu state output.

## Errors

- Disabled menu or wrong label fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("test helper reported error: %s", resp.Error)
	}
	if resp.MenuLabel != "Logs" {
		t.Fatalf("expected menu_label=%q, got %q", "Logs", resp.MenuLabel)
	}
	if !resp.MenuEnabled {
		t.Fatal("expected menu_enabled=true for Logs viewer even when daemon is down")
	}
	t.Logf("menu-label/logs-viewer OK: label=%q enabled=%v", resp.MenuLabel, resp.MenuEnabled)
}
```
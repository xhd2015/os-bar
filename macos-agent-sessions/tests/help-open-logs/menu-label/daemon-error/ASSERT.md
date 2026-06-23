## Expected

- `resp.Error == ""`.
- `resp.MenuLabel == "Open Logs (daemon unreachable)"`.
- `resp.MenuEnabled == false`.

## Side Effects

- No UI automation; only pure menu state output.
- No filesystem access for path resolution.

## Errors

- If `Run` returns an error, the test fails.
- Enabled menu or wrong label fails the test.

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
	wantLabel := "Open Logs (daemon unreachable)"
	if resp.MenuLabel != wantLabel {
		t.Fatalf("expected menu_label=%q, got %q", wantLabel, resp.MenuLabel)
	}
	if resp.MenuEnabled {
		t.Fatal("expected menu_enabled=false when daemon is unreachable")
	}
	t.Logf("menu-label/daemon-error OK: label=%q enabled=%v", resp.MenuLabel, resp.MenuEnabled)
}
```
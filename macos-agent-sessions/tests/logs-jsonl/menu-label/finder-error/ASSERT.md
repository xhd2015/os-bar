## Expected

- `resp.Error == ""`.
- `resp.MenuLabel == "Show Logs in Finder (daemon unreachable)"`.
- `resp.MenuEnabled == false`.

## Side Effects

- No filesystem access for path resolution when daemon is down.

## Errors

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
	want := "Show Logs in Finder (daemon unreachable)"
	if resp.MenuLabel != want {
		t.Fatalf("expected menu_label=%q, got %q", want, resp.MenuLabel)
	}
	if resp.MenuEnabled {
		t.Fatal("expected menu_enabled=false when daemon is unreachable")
	}
	t.Logf("menu-label/finder-error OK: label=%q enabled=%v", resp.MenuLabel, resp.MenuEnabled)
}
```
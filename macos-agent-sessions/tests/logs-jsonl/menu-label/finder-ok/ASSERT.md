## Expected

- `resp.Error == ""`.
- `resp.MenuLabel == "Show Logs in Finder"`.
- `resp.MenuEnabled == true`.

## Side Effects

- No UI automation; only pure `OpenLogsMenuState` output.

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
	want := "Show Logs in Finder"
	if resp.MenuLabel != want {
		t.Fatalf("expected menu_label=%q, got %q", want, resp.MenuLabel)
	}
	if !resp.MenuEnabled {
		t.Fatal("expected menu_enabled=true on successful info")
	}
	t.Logf("menu-label/finder-ok OK: label=%q enabled=%v", resp.MenuLabel, resp.MenuEnabled)
}
```
## Expected

- `resp.Error == ""`.
- `resp.FocusedVSCodeDir == "/proj/b"` for notification path.
- `resp.MenuFocusedVSCodeDir == "/proj/b"` for menu path.
- Menu and notification focused dirs are equal.

## Side Effects

- Parity action runs both click sources against the same VS Code window state.

## Errors

- Divergent focus dirs indicate notification click regressed relative to menu click.

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
	const targetDir = "/proj/b"
	if resp.MenuFocusedVSCodeDir != targetDir {
		t.Fatalf("menu click must focus VS Code window for %q, got %q", targetDir, resp.MenuFocusedVSCodeDir)
	}
	if resp.FocusedVSCodeDir != targetDir {
		t.Fatalf("notification click must focus VS Code window for %q, got %q", targetDir, resp.FocusedVSCodeDir)
	}
	if resp.FocusedVSCodeDir != resp.MenuFocusedVSCodeDir {
		t.Fatalf("menu and notification clicks must focus the same VS Code window: menu=%q notification=%q", resp.MenuFocusedVSCodeDir, resp.FocusedVSCodeDir)
	}
	t.Logf("menu-notification-window-parity OK: menu=%s notification=%s", resp.MenuFocusedVSCodeDir, resp.FocusedVSCodeDir)
}
```
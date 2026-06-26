## Expected

- `resp.Error == ""`.
- `resp.ExecutedCommand == "/usr/local/bin/code /proj/b"`.
- `resp.AppActivated == true`.
- `resp.OpenedDir == "/proj/b"`.
- `resp.ConsumedDir == "/proj/b"`.
- `resp.FocusedVSCodeDir == "/proj/b"` — VS Code must focus the window for the notified directory, not the previously frontmost window.

## Side Effects

- Simulator records which VS Code workspace window ends up frontmost after the full click flow.

## Errors

- `focused_vscode_dir == "/proj/a"` means notification click only foregrounded VS Code on the stale window (the reported bug).
- Missing app activation indicates notification click regressed to menu-bar behavior.

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
	const staleFrontmost = "/proj/a"
	const wantCmd = "/usr/local/bin/code /proj/b"
	if resp.ExecutedCommand != wantCmd {
		t.Fatalf("expected executed_command %q, got %q", wantCmd, resp.ExecutedCommand)
	}
	if !resp.AppActivated {
		t.Fatal("notification click must activate app before opening session")
	}
	if resp.OpenedDir != targetDir {
		t.Fatalf("expected opened_dir %q, got %q", targetDir, resp.OpenedDir)
	}
	if resp.ConsumedDir != targetDir {
		t.Fatalf("expected consumed_dir %q, got %q", targetDir, resp.ConsumedDir)
	}
	if resp.FocusedVSCodeDir != targetDir {
		t.Fatalf("notification click must focus VS Code window for %q, got focused_vscode_dir=%q (stale frontmost was %q)", targetDir, resp.FocusedVSCodeDir, staleFrontmost)
	}
	t.Logf("notification-focuses-target-window OK: focused=%s", resp.FocusedVSCodeDir)
}
```
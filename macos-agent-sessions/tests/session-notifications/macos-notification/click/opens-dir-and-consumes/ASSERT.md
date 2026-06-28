## Expected

- `resp.Error == ""`.
- `resp.AppActivated == true`.
- `resp.WindowOpened == false`.
- `resp.ExecutedCommand == "/usr/local/bin/kool vscode open /proj/x --ipc-only --json"`.
- `resp.OpenMethod == "kool_ipc"`.
- `resp.OpenedDir == "/proj/x"`.
- `resp.ConsumedDir == "/proj/x"`.

## Side Effects

- Test helper records activate-app-then-open+consume intent without launching real `code` binary or AppKit calls.

## Errors

- Missing app activation indicates notification click regressed to menu-bar behavior.
- Window opened on notification click violates LSUIElement activation contract.
- Mismatched opened/consumed dirs indicate broken click handler wiring.

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
	const dir = "/proj/x"
	const wantCmd = "/usr/local/bin/kool vscode open /proj/x --ipc-only --json"
	if !resp.AppActivated {
		t.Fatal("notification click must activate app before opening session")
	}
	if resp.WindowOpened {
		t.Fatal("notification click must not open a new window")
	}
	if resp.ExecutedCommand != wantCmd {
		t.Fatalf("expected executed_command %q, got %q", wantCmd, resp.ExecutedCommand)
	}
	if resp.OpenedDir != dir {
		t.Fatalf("expected opened_dir %q, got %q", dir, resp.OpenedDir)
	}
	if resp.ConsumedDir != dir {
		t.Fatalf("expected consumed_dir %q, got %q", dir, resp.ConsumedDir)
	}
	if resp.OpenMethod != "kool_ipc" {
		t.Fatalf("expected open_method kool_ipc, got %q", resp.OpenMethod)
	}
	t.Logf("opens-dir-and-consumes OK: activated=%v cmd=%s", resp.AppActivated, resp.ExecutedCommand)
}
```
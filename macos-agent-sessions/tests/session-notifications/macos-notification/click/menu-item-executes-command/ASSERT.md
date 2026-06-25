## Expected

- `resp.Error == ""`.
- `resp.ExecutedCommand == "/usr/local/bin/code /proj/x"`.
- `resp.AppActivated == false`.
- `resp.WindowOpened == false`.
- `resp.OpenedDir == "/proj/x"`.
- `resp.ConsumedDir == "/proj/x"`.

## Side Effects

- Test helper records command execution intent only; no real process launch.

## Errors

- App activation on menu click indicates incorrect source handling.
- Missing or wrong command line indicates broken open-session wiring.

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
	const wantCmd = "/usr/local/bin/code /proj/x"
	if resp.ExecutedCommand != wantCmd {
		t.Fatalf("expected executed_command %q, got %q", wantCmd, resp.ExecutedCommand)
	}
	if resp.AppActivated {
		t.Fatal("menu item click must not activate app")
	}
	if resp.WindowOpened {
		t.Fatal("menu item click must not open a window")
	}
	if resp.OpenedDir != dir {
		t.Fatalf("expected opened_dir %q, got %q", dir, resp.OpenedDir)
	}
	if resp.ConsumedDir != dir {
		t.Fatalf("expected consumed_dir %q, got %q", dir, resp.ConsumedDir)
	}
	t.Logf("menu-item-executes-command OK: cmd=%s", resp.ExecutedCommand)
}
```
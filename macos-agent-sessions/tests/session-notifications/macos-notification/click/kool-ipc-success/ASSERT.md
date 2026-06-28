## Expected

- `resp.OpenMethod == "kool_ipc"`.
- `resp.KoolAttempted == true`.
- `resp.KoolIpcHandled == true`.
- `resp.CodeExecuted == false`.
- `resp.ExecutedCommand == "/usr/local/bin/kool vscode open /proj/b --ipc-only --json"`.
- `resp.FallbackReason == ""`.

## Errors

- Any `code_cli` execution means kool IPC success path was skipped incorrectly.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	const dir = "/proj/b"
	const wantCmd = "/usr/local/bin/kool vscode open /proj/b --ipc-only --json"
	if resp.ExecutedCommand != wantCmd {
		t.Fatalf("executed_command=%q want %q", resp.ExecutedCommand, wantCmd)
	}
	if resp.OpenMethod != "kool_ipc" {
		t.Fatalf("open_method=%q want kool_ipc", resp.OpenMethod)
	}
	if !resp.KoolAttempted || !resp.KoolIpcHandled {
		t.Fatalf("kool_attempted=%v kool_ipc_handled=%v", resp.KoolAttempted, resp.KoolIpcHandled)
	}
	if resp.CodeExecuted {
		t.Fatal("code CLI must not run when kool IPC handled")
	}
	if resp.FallbackReason != "" {
		t.Fatalf("unexpected fallback_reason %q", resp.FallbackReason)
	}
	if resp.OpenedDir != dir || resp.ConsumedDir != dir {
		t.Fatalf("opened/consumed dir mismatch: opened=%q consumed=%q", resp.OpenedDir, resp.ConsumedDir)
	}
}
```
## Expected

- `resp.ResolvedKoolBin == "/usr/bin/kool"`.
- `resp.ExecutedCommand == "/usr/bin/kool vscode open /proj/b --ipc-only --json"`.
- `resp.OpenMethod == "kool_ipc"`.

## Errors

- Using `/usr/local/bin/kool` when `/usr/bin/kool` is present violates candidate order.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	if resp.ResolvedKoolBin != "/usr/bin/kool" {
		t.Fatalf("resolved_kool_bin=%q want /usr/bin/kool", resp.ResolvedKoolBin)
	}
	const wantCmd = "/usr/bin/kool vscode open /proj/b --ipc-only --json"
	if resp.ExecutedCommand != wantCmd {
		t.Fatalf("executed_command=%q want %q", resp.ExecutedCommand, wantCmd)
	}
	if resp.OpenMethod != "kool_ipc" {
		t.Fatalf("open_method=%q", resp.OpenMethod)
	}
}
```
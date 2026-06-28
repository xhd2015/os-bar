## Expected

- `resp.OpenMethod == "code_cli"`.
- `resp.KoolAttempted == true`.
- `resp.KoolIpcHandled == false`.
- `resp.FallbackReason == "kool_ipc_not_handled"`.
- `resp.CodeExecuted == true`.
- Final `executed_command` is `/usr/local/bin/code /proj/b` (consolidated log uses code command).

## Side Effects

- Single open attempt records kool probe fields plus final code command (not two log lines).

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	const wantCmd = "/usr/local/bin/code /proj/b"
	if resp.ExecutedCommand != wantCmd {
		t.Fatalf("executed_command=%q want %q", resp.ExecutedCommand, wantCmd)
	}
	if resp.OpenMethod != "code_cli" {
		t.Fatalf("open_method=%q want code_cli", resp.OpenMethod)
	}
	if !resp.KoolAttempted || resp.KoolIpcHandled {
		t.Fatalf("kool_attempted=%v kool_ipc_handled=%v", resp.KoolAttempted, resp.KoolIpcHandled)
	}
	if resp.FallbackReason != "kool_ipc_not_handled" {
		t.Fatalf("fallback_reason=%q", resp.FallbackReason)
	}
	if !resp.CodeExecuted {
		t.Fatal("expected code CLI fallback execution")
	}
}
```
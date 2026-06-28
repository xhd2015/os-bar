## Expected

- `resp.OpenMethod == "code_cli"`.
- `resp.KoolAttempted == false`.
- `resp.FallbackReason == "kool_missing"`.
- `resp.ExecutedCommand == "/usr/local/bin/code /proj/b"`.
- `resp.ResolvedKoolBin == ""`.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	if resp.KoolAttempted {
		t.Fatal("kool must not be attempted when binary missing")
	}
	if resp.FallbackReason != "kool_missing" {
		t.Fatalf("fallback_reason=%q want kool_missing", resp.FallbackReason)
	}
	if resp.OpenMethod != "code_cli" {
		t.Fatalf("open_method=%q want code_cli", resp.OpenMethod)
	}
	if resp.ExecutedCommand != "/usr/local/bin/code /proj/b" {
		t.Fatalf("executed_command=%q", resp.ExecutedCommand)
	}
	if resp.ResolvedKoolBin != "" {
		t.Fatalf("resolved_kool_bin=%q want empty", resp.ResolvedKoolBin)
	}
}
```
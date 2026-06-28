## Expected

- `resp.KoolAttempted == false`.
- `resp.OpenMethod == "code_cli"` (or empty before field exists — assert code path).
- `resp.ExecutedCommand == "/usr/local/bin/code /proj/b"`.
- `resp.ResolvedKoolBin == ""`.

## Out of Scope

- Menu bar must not call kool per product decision.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("test helper error: %s", resp.Error)
	}
	if resp.KoolAttempted {
		t.Fatal("menu click must not attempt kool")
	}
	if resp.ExecutedCommand != "/usr/local/bin/code /proj/b" {
		t.Fatalf("executed_command=%q", resp.ExecutedCommand)
	}
	if resp.OpenMethod != "" && resp.OpenMethod != "code_cli" {
		t.Fatalf("open_method=%q want code_cli or empty", resp.OpenMethod)
	}
	if resp.ResolvedKoolBin != "" {
		t.Fatalf("menu must not resolve kool binary, got %q", resp.ResolvedKoolBin)
	}
}
```
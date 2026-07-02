## Expected

- `resp.HTTPStatus` = 200
- `resp.OK` = true
- `resp.OpenMethodUsed` = `"vscode"` (explicit overrides config)

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200, got %d: body=%s", resp.HTTPStatus, resp.HTTPBody)
	}
	if !resp.OK {
		t.Fatalf("expected ok=true, got ok=false: body=%s", resp.HTTPBody)
	}
	if resp.OpenMethodUsed != "vscode" {
		t.Fatalf("expected open_method_used=vscode (explicit override), got %q: body=%s", resp.OpenMethodUsed, resp.HTTPBody)
	}
	t.Logf("OK: explicit open_method overrides config")
}
```
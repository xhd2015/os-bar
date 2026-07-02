## Expected

- `resp.HTTPStatus` = 200
- `resp.ConfigMethod` = `"vscode"`

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200, got %d: body=%s", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.ConfigMethod != "vscode" {
		t.Fatalf("expected open_method=vscode, got %q", resp.ConfigMethod)
	}
	t.Logf("OK: config default is vscode")
}
```
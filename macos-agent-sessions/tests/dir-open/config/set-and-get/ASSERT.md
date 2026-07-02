## Expected

- `resp.HTTPStatus` = 200
- `resp.ConfigMethod` = `"iterm2"`

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200, got %d: body=%s", resp.HTTPStatus, resp.HTTPBody)
	}
	if resp.ConfigMethod != "iterm2" {
		t.Fatalf("expected open_method=iterm2, got %q (body=%s)", resp.ConfigMethod, resp.HTTPBody)
	}
	t.Logf("OK: config set to iterm2 and verified")
}
```
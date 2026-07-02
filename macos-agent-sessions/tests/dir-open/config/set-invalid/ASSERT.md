## Expected

- `resp.HTTPStatus` = 400

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.HTTPStatus != 400 {
		t.Fatalf("expected HTTP 400, got %d: body=%s", resp.HTTPStatus, resp.HTTPBody)
	}
	t.Logf("OK: invalid open_method rejected: %s", resp.HTTPBody)
}
```
## Expected

- `resp.HTTPStatus == 404`.

## Errors

- Status other than 404 fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 404 {
		t.Fatalf("expected HTTP 404 for POST /api/wrong, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	t.Log("sessions-api/wrong-path OK")
}
```
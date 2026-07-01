## Expected

- `resp.HTTPStatus == 405`.

## Errors

- Status other than 405 fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 405 {
		t.Fatalf("expected HTTP 405 for GET /api/events/consume-all, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	t.Log("sessions-api/consume-all-wrong-method OK")
}
```

## Expected

- `resp.HTTPStatus == 200`.
- `len(resp.Events) == 0`.
- `resp.HTTPBody` parses as empty JSON array `[]`.

## Errors

- Non-200 status fails the test.
- Any events in fresh daemon fail the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 200 {
		t.Fatalf("expected HTTP 200, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	if len(resp.Events) != 0 {
		t.Fatalf("expected empty list, got %d events", len(resp.Events))
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Log("sessions-api/list-empty OK")
}
```
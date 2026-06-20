## Expected

- `resp.HTTPStatus == 400`.
- No session events created.

## Errors

- Status other than 400 fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.HTTPStatus != 400 {
		t.Fatalf("expected HTTP 400 for missing dir, got %d body=%q", resp.HTTPStatus, resp.HTTPBody)
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Log("sessions-api/missing-dir OK")
}
```
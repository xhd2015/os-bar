## Expected

- DELETE returns HTTP 200.
- Final list: `len(resp.Events) == 0`.

## Side Effects

- `events.json` no longer contains `/proj` after delete.

## Errors

- Non-empty list after delete fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if len(resp.Events) != 0 {
		t.Fatalf("expected empty list after delete, got %d events", len(resp.Events))
	}
	assertStateDirIsolated(t, resp.StateDir)
	t.Log("sessions-api/delete-events OK")
}
```
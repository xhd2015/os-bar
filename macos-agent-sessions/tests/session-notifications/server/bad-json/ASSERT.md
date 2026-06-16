## Expected
- `resp.HTTPStatus == 400`.
- `resp.Count == 0` (no event stored).
- `resp.Error == ""` (test helper itself did not error).

## Errors
- If HTTP status is not 400, the test fails.
- If an event was stored (count > 0), the test fails.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("test helper reported error: %s", resp.Error)
	}

	if resp.HTTPStatus != 400 {
		t.Fatalf("expected http_status=400 for bad JSON, got %d; body=%s", resp.HTTPStatus, resp.HTTPBody)
	}

	if resp.Count != 0 {
		t.Fatalf("expected count=0 (no event stored for bad request), got count=%d; events=%+v", resp.Count, resp.Events)
	}

	t.Logf("bad-json OK: http_status=%d, count=%d", resp.HTTPStatus, resp.Count)
}
```

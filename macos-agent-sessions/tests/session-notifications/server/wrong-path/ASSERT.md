## Expected
- `resp.HTTPStatus == 404`.
- `resp.Count == 0` (no event stored).
- `resp.Error == ""`.

## Errors
- If HTTP status is not 404, the test fails.
- If an event was stored despite the wrong path, the test fails.

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

	if resp.HTTPStatus != 404 {
		t.Fatalf("expected http_status=404 for POST /api/wrong, got %d; body=%s", resp.HTTPStatus, resp.HTTPBody)
	}

	if resp.Count != 0 {
		t.Fatalf("expected count=0 (no event stored for wrong path), got count=%d; events=%+v", resp.Count, resp.Events)
	}

	t.Logf("wrong-path OK: http_status=%d", resp.HTTPStatus)
}
```

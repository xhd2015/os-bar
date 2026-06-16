## Expected
- `resp.HTTPStatus == 405`.
- `resp.Count == 0` (no event stored).
- `resp.Error == ""`.

## Errors
- If HTTP status is not 405, the test fails.
- If an event was stored despite the wrong method, the test fails.

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

	if resp.HTTPStatus != 405 {
		t.Fatalf("expected http_status=405 for GET /api/notify, got %d; body=%s", resp.HTTPStatus, resp.HTTPBody)
	}

	if resp.Count != 0 {
		t.Fatalf("expected count=0 (no event stored for wrong method), got count=%d; events=%+v", resp.Count, resp.Events)
	}

	t.Logf("wrong-method OK: http_status=%d", resp.HTTPStatus)
}
```

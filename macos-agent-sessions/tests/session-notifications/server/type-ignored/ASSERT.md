## Expected
- `resp.HTTPStatus == 200`.
- `resp.HTTPBody` contains `"ok"`.
- `resp.Count == 1`.
- `resp.Events[0].Dir == "/Users/test/cursor-project"`.
- `resp.Error == ""`.

## Context
- The `type` field is not stored anywhere — it is present only in the raw JSON body, not in `SessionEvent`.
- This is verified implicitly because `SessionEvent` has no `type` property.

## Errors
- If HTTP status is not 200, the test fails.
- If the dir is not stored, the test fails.

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

	if resp.HTTPStatus != 200 {
		t.Fatalf("expected http_status=200, got %d; body=%s", resp.HTTPStatus, resp.HTTPBody)
	}

	if resp.Count != 1 {
		t.Fatalf("expected count=1, got count=%d", resp.Count)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(resp.Events))
	}
	if resp.Events[0].Dir != "/Users/test/cursor-project" {
		t.Fatalf("expected dir=/Users/test/cursor-project, got dir=%s", resp.Events[0].Dir)
	}

	t.Logf("type-ignored OK: http_status=%d, dir stored, type field ignored", resp.HTTPStatus)
}
```

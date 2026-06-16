## Expected
- `resp.HTTPStatus == 200`.
- `resp.HTTPBody` contains `"ok"` (specifically `{"ok":true}`).
- `resp.Count == 1`.
- `resp.Events[0].Dir == "/Users/test/server-project"`.
- `resp.Error == ""`.

## Errors
- If HTTP status is not 200, the test fails.
- If the event is not stored, the test fails.
- If `Run` returns an error, the test fails.

```go
import "strings"

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

	if !strings.Contains(resp.HTTPBody, `"ok"`) {
		t.Fatalf("expected response body to contain ok, got %s", resp.HTTPBody)
	}

	if resp.Count != 1 {
		t.Fatalf("expected count=1 after post-notify, got count=%d", resp.Count)
	}
	if len(resp.Events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(resp.Events))
	}
	if resp.Events[0].Dir != "/Users/test/server-project" {
		t.Fatalf("expected dir=/Users/test/server-project, got dir=%s", resp.Events[0].Dir)
	}

	t.Logf("post-notify OK: http_status=%d, body=%s, count=%d", resp.HTTPStatus, resp.HTTPBody, resp.Count)
}
```

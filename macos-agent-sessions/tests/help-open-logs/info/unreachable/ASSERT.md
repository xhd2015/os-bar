## Expected

- `resp.Error != ""` (connection refused, connection reset, or similar dial failure).
- `resp.StoragePath == ""`.
- `resp.HTTPStatus == 0` (no successful HTTP response).

## Side Effects

- No daemon process started.
- No filesystem writes under real `~/.os-bar/`.

## Errors

- If `Run` returns a Go error, the test fails.
- If the HTTP request unexpectedly succeeds, `resp.Error` contains a sentinel message.

```go
import (
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error == "" {
		t.Fatal("expected non-empty error for unreachable daemon")
	}
	lower := strings.ToLower(resp.Error)
	if !strings.Contains(lower, "connect") &&
		!strings.Contains(lower, "refused") &&
		!strings.Contains(lower, "dial") &&
		!strings.Contains(lower, "connection") {
		t.Fatalf("expected connection-related error, got %q", resp.Error)
	}
	if resp.StoragePath != "" {
		t.Fatalf("expected empty storage_path on error, got %q", resp.StoragePath)
	}
	if resp.HTTPStatus != 0 {
		t.Fatalf("expected HTTPStatus 0 on connection failure, got %d", resp.HTTPStatus)
	}
	t.Logf("info/unreachable OK: error=%q", resp.Error)
}
```
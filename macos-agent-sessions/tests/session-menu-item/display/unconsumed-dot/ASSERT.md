## Expected

- `resp.Error == ""`.
- `resp.DisplayLabel` starts with `● `.

## Errors

- Missing bullet prefix fails the test.

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
	if !strings.HasPrefix(resp.DisplayLabel, "● ") {
		t.Fatalf("expected display_label to start with %q, got %q", "● ", resp.DisplayLabel)
	}
	t.Logf("display/unconsumed-dot OK: display_label=%q", resp.DisplayLabel)
}
```
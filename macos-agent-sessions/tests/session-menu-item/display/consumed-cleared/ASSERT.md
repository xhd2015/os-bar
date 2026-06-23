## Expected

- `resp.Error == ""`.
- `resp.DisplayLabel` starts with `  ` (two spaces, no bullet).

## Errors

- Bullet prefix on consumed row fails the test.

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
	if !strings.HasPrefix(resp.DisplayLabel, "  ") {
		t.Fatalf("expected display_label to start with two spaces, got %q", resp.DisplayLabel)
	}
	if strings.HasPrefix(resp.DisplayLabel, "● ") {
		t.Fatalf("consumed display_label must not start with bullet: %q", resp.DisplayLabel)
	}
	t.Logf("display/consumed-cleared OK: display_label=%q", resp.DisplayLabel)
}
```
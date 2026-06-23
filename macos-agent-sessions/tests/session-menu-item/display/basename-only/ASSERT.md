## Expected

- `resp.Error == ""`.
- `resp.DisplayLabel` is non-empty.
- `resp.DisplayLabel` contains basename `my-app`.
- `resp.DisplayLabel` does **not** contain full path `/Users/me/a/b/c/my-app`.
- `resp.DisplayLabel` contains relative time `5m ago`.

## Side Effects

- No UI rendering; formatter only.

## Errors

- Full path leaking into display label fails the test.

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
	line := resp.DisplayLabel
	if strings.TrimSpace(line) == "" {
		t.Fatal("expected non-empty display_label")
	}
	if !strings.Contains(line, "my-app") {
		t.Fatalf("display_label %q must contain basename %q", line, "my-app")
	}
	if strings.Contains(line, "/Users/me/a/b/c/my-app") {
		t.Fatalf("display_label should use basename, not full path: %q", line)
	}
	if !strings.Contains(line, "5m ago") {
		t.Fatalf("display_label %q must contain relative time %q", line, "5m ago")
	}
	t.Logf("display/basename-only OK: display_label=%q", line)
}
```
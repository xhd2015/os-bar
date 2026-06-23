## Expected

- `resp.Error == ""`.
- `resp.DisplayLine` is non-empty.
- `resp.DisplayLine` contains the entry **timestamp** (`2026-06-23T12:00:00Z` or formatted equivalent).
- `resp.DisplayLine` contains the **source** (`pi`).
- `resp.DisplayLine` contains the dir **basename** (`my-app`), not the full path.

## Side Effects

- No UI rendering; only formatted string from `LogsViewModel` / formatter helper.

## Errors

- Missing timestamp, source, or basename in display line fails the test.

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
	line := resp.DisplayLine
	if strings.TrimSpace(line) == "" {
		t.Fatal("expected non-empty display_line")
	}
	for _, substr := range []string{"2026-06-23", "pi", "my-app"} {
		if !strings.Contains(line, substr) {
			t.Fatalf("display_line %q must contain %q", line, substr)
		}
	}
	if strings.Contains(line, "/Users/me/proj/my-app") {
		t.Fatalf("display_line should use basename, not full path: %q", line)
	}
	t.Logf("viewer/format-entry OK: display_line=%q", line)
}
```
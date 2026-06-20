## Expected
- `resp.WindowOpen == true`.
- `resp.Layout` contains identifier `integrations-window`.
- Layout contains all four row identifiers: `integration-grok`, `integration-opencode`, `integration-pi`, `integration-codex`.
- `resp.Error == ""`.

## Errors
- If window does not open, test fails.
- If any row identifier is absent from layout tree, test fails.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.WindowOpen != true {
		t.Fatal("expected window_open=true")
	}
	if resp.Layout == nil {
		t.Fatal("expected non-nil layout")
	}
	if !layoutContainsIdentifier(resp.Layout, "integrations-window") {
		t.Fatal("layout missing integrations-window identifier")
	}
	rowIDs := []string{
		"integration-grok",
		"integration-opencode",
		"integration-pi",
		"integration-codex",
	}
	for _, id := range rowIDs {
		if !layoutContainsIdentifier(resp.Layout, id) {
			t.Fatalf("layout missing row identifier %q", id)
		}
	}

	t.Logf("window/open/window-visible OK: rows=%d", len(rowIDs))
}
```
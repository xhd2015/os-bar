## Expected

- `resp.Error == ""`.
- `resp.ButtonLabel == "Mark All Read"` (constant; the non-empty state does not change the label).
- `resp.ButtonEnabled == true` (at least one unconsumed event → actionable).
- `resp.UnconsumedCount >= 1`.

## Errors

- `button_enabled == false` when `unconsumed_count >= 1` fails the test.
- A label other than `"Mark All Read"` fails the test.

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
	if resp.ButtonLabel != "Mark All Read" {
		t.Fatalf("expected button_label=%q, got %q", "Mark All Read", resp.ButtonLabel)
	}
	if !resp.ButtonEnabled {
		t.Fatalf("expected button_enabled=true when unconsumed_count>=1, got false")
	}
	if resp.UnconsumedCount < 1 {
		t.Fatalf("expected unconsumed_count>=1, got %d", resp.UnconsumedCount)
	}
	t.Logf("state/enabled-when-some OK: enabled=%v count=%d", resp.ButtonEnabled, resp.UnconsumedCount)
}
```

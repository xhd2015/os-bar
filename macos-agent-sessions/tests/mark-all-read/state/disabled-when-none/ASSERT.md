## Expected

- `resp.Error == ""`.
- `resp.ButtonLabel == "Mark All Read"` (constant; the empty state does not change the label).
- `resp.ButtonEnabled == false` (no unconsumed events → greyed out).
- `resp.UnconsumedCount == 0`.

## Errors

- `button_enabled == true` when `unconsumed_count == 0` fails the test.
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
	if resp.ButtonEnabled {
		t.Fatalf("expected button_enabled=false when unconsumed_count=0, got true")
	}
	if resp.UnconsumedCount != 0 {
		t.Fatalf("expected unconsumed_count=0, got %d", resp.UnconsumedCount)
	}
	t.Logf("state/disabled-when-none OK: enabled=%v count=%d", resp.ButtonEnabled, resp.UnconsumedCount)
}
```

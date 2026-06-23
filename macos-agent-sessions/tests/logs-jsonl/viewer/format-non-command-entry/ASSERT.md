## Expected

- `resp.Error == ""`.
- `resp.DetailLines` is empty (`nil` or `len == 0`).

## Side Effects

- No UI rendering; formatter returns empty array for non-`command.executed` events.

## Errors

- Any non-empty `detail_lines` fails the test.

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
	if len(resp.DetailLines) != 0 {
		t.Fatalf("expected empty detail_lines for event=stop, got %v", resp.DetailLines)
	}
	t.Logf("viewer/format-non-command-entry OK: detail_lines empty")
}
```
## Expected

- `resp.FormatResult == "100MB"`.

## Errors

- GB label or decimal fraction fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	const want = "100MB"
	if resp.FormatResult != want {
		t.Fatalf("FormatBytes(104857600): got %q, want %q", resp.FormatResult, want)
	}
	t.Logf("swap-format-used OK: %q", resp.FormatResult)
}
```
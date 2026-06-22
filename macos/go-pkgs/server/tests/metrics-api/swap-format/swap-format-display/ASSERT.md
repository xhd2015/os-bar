## Expected

- `resp.FormatResult == "5% (100MB/2GB)"`.
- Rounded integer percent, then used/total inside parentheses.

## Errors

- Wrong percent, reversed used/total order, or decimal fractions fail the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	const want = "5% (100MB/2GB)"
	if resp.FormatResult != want {
		t.Fatalf("FormatSwapDisplay(2147483648, 104857600): got %q, want %q", resp.FormatResult, want)
	}
	t.Logf("swap-format-display OK: %q", resp.FormatResult)
}
```
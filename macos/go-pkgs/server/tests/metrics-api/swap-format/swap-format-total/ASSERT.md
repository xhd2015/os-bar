## Expected

- `resp.FormatResult == "2GB"`.

## Errors

- Any other string (decimals, SI units, wrong magnitude) fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	const want = "2GB"
	if resp.FormatResult != want {
		t.Fatalf("FormatBytes(2147483648): got %q, want %q", resp.FormatResult, want)
	}
	t.Logf("swap-format-total OK: %q", resp.FormatResult)
}
```
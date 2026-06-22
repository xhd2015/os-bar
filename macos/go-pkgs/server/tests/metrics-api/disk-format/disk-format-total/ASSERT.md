## Expected

- `resp.FormatResult == "500GB"`.

## Errors

- Decimal labels or wrong magnitude fail the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	const want = "500GB"
	if resp.FormatResult != want {
		t.Fatalf("FormatDiskBytesBinaryTotal(536870912000): got %q, want %q", resp.FormatResult, want)
	}
	t.Logf("disk-format-total OK: %q", resp.FormatResult)
}
```
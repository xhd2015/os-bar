## Expected

- `resp.FormatResult == "200.00GB"`.

## Errors

- Integer-only labels or wrong magnitude fail the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	const want = "200.00GB"
	if resp.FormatResult != want {
		t.Fatalf("FormatDiskBytesBinaryUsed(214748364800): got %q, want %q", resp.FormatResult, want)
	}
	t.Logf("disk-format-used OK: %q", resp.FormatResult)
}
```
## Expected

- `resp.FormatResult == "0B"`.

## Errors

- Empty string, `0`, or unitless zero fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	const want = "0B"
	if resp.FormatResult != want {
		t.Fatalf("FormatDiskBytes(0): got %q, want %q", resp.FormatResult, want)
	}
	t.Logf("disk-format-zero OK: %q", resp.FormatResult)
}
```
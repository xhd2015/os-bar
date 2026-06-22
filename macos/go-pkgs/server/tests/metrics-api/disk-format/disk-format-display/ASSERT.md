## Expected

- `resp.FormatResult == "40% (200.00GB/500GB, 214.75GB/536.87GB on MacOS Settings)"`.
- Rounded integer percent; 1024-based pair first, then decimal pair with suffix.

## Errors

- Wrong percent, reversed order, or missing `on MacOS Settings` suffix fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	const want = "40% (200.00GB/500GB, 214.75GB/536.87GB on MacOS Settings)"
	if resp.FormatResult != want {
		t.Fatalf("FormatDiskDisplay(536870912000, 214748364800): got %q, want %q", resp.FormatResult, want)
	}
	t.Logf("disk-format-display OK: %q", resp.FormatResult)
}
```
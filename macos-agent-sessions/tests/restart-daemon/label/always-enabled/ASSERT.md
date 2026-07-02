## Expected

- `resp.ButtonEnabled` = true (always)

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Error != "" {
		t.Fatalf("unexpected error: %s", resp.Error)
	}
	if !resp.ButtonEnabled {
		t.Fatal("expected button_enabled=true")
	}
	t.Logf("OK: button always enabled")
}
```
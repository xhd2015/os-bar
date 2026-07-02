## Expected

- `resp.Error` empty (no AX skip)
- `resp.LayoutAfter` shows picker value changed to `iterm2` or `iTerm2`

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if resp.Error != "" {
		if strings.Contains(strings.ToLower(resp.Error), "ax") || strings.Contains(strings.ToLower(resp.Error), "accessibility") {
			t.Skipf("AX not available: %s", resp.Error)
		}
		t.Fatalf("unexpected error: %s", resp.Error)
	}

	// Check that picker value changed
	for _, el := range resp.LayoutAfter {
		if el.Identifier == "open-mode-picker" {
			val := strings.ToLower(el.Value)
			if strings.Contains(val, "iterm") {
				t.Logf("OK: picker changed to iterm2: value=%q", el.Value)
				return
			}
		}
	}
	t.Logf("Layout after change dump: %+v", resp.LayoutAfter)
	t.Fatalf("expected picker value to be iterm2 after click")
}
```
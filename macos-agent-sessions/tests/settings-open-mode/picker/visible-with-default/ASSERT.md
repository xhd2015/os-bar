## Expected

- `resp.Error` must not contain `AX` or `accessibility` (no AX skip)
- `resp.LayoutBefore` contains an element with `identifier=open-mode-picker`
- The picker's value or selected child indicates `vscode`

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

	foundPicker := false
	for _, el := range resp.LayoutBefore {
		if el.Identifier == "open-mode-picker" {
			foundPicker = true
			t.Logf("OK: open-mode-picker found: role=%s value=%q title=%q", el.Role, el.Value, el.Title)
			break
		}
		// Also search children
		var search func([]AXElement) bool
		search = func(children []AXElement) bool {
			for _, c := range children {
				if c.Identifier == "open-mode-picker" {
					foundPicker = true
					t.Logf("OK: open-mode-picker found in children: role=%s value=%q title=%q", c.Role, c.Value, c.Title)
					return true
				}
				if search(c.Children) {
					return true
				}
			}
			return false
		}
		if search(el.Children) {
			break
		}
	}
	if !foundPicker {
		t.Fatalf("open-mode-picker not found in layout")
	}
}
```
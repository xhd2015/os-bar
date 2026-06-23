## Expected

- `resp.Error == ""`.
- `resp.MenuTooltip == "/Users/me/work/my-app"`.
- `resp.MenuTooltip == req.Dir`.

## Side Effects

- No UI rendering; formatter only.

## Errors

- Empty or mismatched tooltip fails the test.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("test helper reported error: %s", resp.Error)
	}
	want := "/Users/me/work/my-app"
	if resp.MenuTooltip != want {
		t.Fatalf("expected menu_tooltip=%q, got %q", want, resp.MenuTooltip)
	}
	if resp.MenuTooltip != req.Dir {
		t.Fatalf("menu_tooltip %q must equal req.Dir %q", resp.MenuTooltip, req.Dir)
	}
	t.Logf("tooltip/full-path OK: menu_tooltip=%q", resp.MenuTooltip)
}
```
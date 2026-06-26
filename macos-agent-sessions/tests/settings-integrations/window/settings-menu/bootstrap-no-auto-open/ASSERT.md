---
label: ui-automation, slow, requires-accessibility
explanation: Normal app launch without -uiTestingOpenSettings; verifies Integrations window stays closed on bootstrap.
---

## Expected
- `resp.WindowVisible == false`.
- `resp.WindowOpen == false`.
- `resp.Error == ""`.

## Side Effects
- App process started and daemon healthy; no Integrations window created.

## Errors
- If Integrations window is visible or open after normal launch, test fails.

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.WindowVisible {
		t.Fatal("expected window_visible=false after normal launch")
	}
	if resp.WindowOpen {
		t.Fatal("expected window_open=false after normal launch")
	}
	t.Logf("settings-menu/bootstrap-no-auto-open OK")
}
```
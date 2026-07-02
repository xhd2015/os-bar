# Scenario

**Feature**: AX dump of Settings window → open-mode-picker exists with vscode selected

---
label: ui-automation, slow, requires-accessibility
explanation: Launches debug .app, opens Settings, AX-dumps picker, verifies vscode selected. Requires Accessibility.
---

## Steps

1. Launch app with `-uiTestingOpenSettings`; wait for daemon ready.
2. Dump AX layout.
3. Assert `open-mode-picker` exists with value `vscode`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Sequence = []Request{
		{Action: "open_settings"},
		{Action: "dump_layout"},
		{Action: "teardown"},
	}
	return nil
}
```
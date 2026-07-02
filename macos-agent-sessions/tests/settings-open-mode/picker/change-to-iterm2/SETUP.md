# Scenario

**Feature**: AX-click iTerm2 option in picker → daemon config changes to iterm2

---
label: ui-automation, slow, requires-accessibility
explanation: Launches debug .app, opens Settings, clicks iTerm2 option, dumps layout, verifies config changed. Requires Accessibility.
---

## Steps

1. Launch app with `-uiTestingOpenSettings`; wait for daemon ready.
2. Dump initial layout.
3. Click `open-mode-option-iterm2` AX element.
4. Dump layout again.
5. Verify daemon config is now `iterm2` via `GET /api/config`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Sequence = []Request{
		{Action: "open_settings"},
		{Action: "dump_layout"},
		{Action: "click", OpenMethod: "iterm2"},
		{Action: "dump_layout"},
		{Action: "teardown"},
	}
	return nil
}
```
# Scenario

**Feature**: Settings window picker UI — AX-identified open mode picker

## Preconditions

- The app accepts `-uiTestingOpenSettings` to open the Settings window directly.
- `UIAutomationHelper.swift` is built and available.
- Accessibility permission is granted for the test runner.
- Tests are labeled `ui-automation, slow, requires-accessibility` and will skip when AX is unavailable.

## Steps

1. Run AX sequence actions via `UIAutomationHelper`:
   - `open_settings` — launch app + open window
   - `dump_layout` — capture AX tree
   - `click` — click an AX-identified element
2. Picker AX identifiers: `open-mode-picker` (parent), `open-mode-option-vscode`, `open-mode-option-iterm2`.
3. Verify config daemon state after picker change.

## Context

- AX sequence actions are dispatched through the helper's stdin/stdout protocol.
- Picker changes persist to daemon config via `POST /api/config`.
- Tests skip with `t.Skip` if AX returns `kAXErrorAPIDisabled`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionAXSequence
	if req.HomeDir == "" {
		req.HomeDir = filepath.Join(t.TempDir(), "home")
		os.MkdirAll(req.HomeDir, 0755)
	}
	return nil
}
```
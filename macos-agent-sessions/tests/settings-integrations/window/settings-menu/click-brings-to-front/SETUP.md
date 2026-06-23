# Scenario

**Feature**: repeat Settings… click brings already-open window to front

```
# open window, obscure it, click Settings… again
launch_app -> click Settings… -> dump_layout -> obscure_window -> click Settings… -> check_window_front
```

## Steps
1. Run sequence: `launch_app` → `click_settings_menu` → `dump_layout` → `obscure_window` → `click_settings_menu` → `check_window_front` → `teardown`.
2. First click+dump confirms window open; `obscure_window` lowers it via AX only.
3. Second click should activate app and raise Integrations (`AXMain`).

## Context
- Validates R3: repeat Settings… click activates app and brings window to front.
- `obscure_window` must not activate another application.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "sequence"
	req.Sequence = []Request{
		{Action: "launch_app"},
		{Action: "click_settings_menu"},
		{Action: "dump_layout"},
		{Action: "obscure_window"},
		{Action: "click_settings_menu", WaitMs: 300},
		{Action: "check_window_front"},
		{Action: "teardown"},
	}
	return nil
}
```
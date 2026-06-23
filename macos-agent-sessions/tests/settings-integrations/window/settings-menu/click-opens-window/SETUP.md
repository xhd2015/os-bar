# Scenario

**Feature**: Settings… menu click opens Integrations window when closed

```
# closed window path: menu click creates and shows Integrations
launch_app -> click Settings… -> dump_layout (integrations-window + 4 rows)
```

## Steps
1. Run sequence: `launch_app` → `click_settings_menu` → `dump_layout` → `teardown`.
2. Capture `resp.WindowOpen` and `resp.Layout`.

## Context
- Validates R2: first Settings… click opens the Integrations window.
- Empty `fakeHome`: all four integration rows still present.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "sequence"
	req.Sequence = []Request{
		{Action: "launch_app"},
		{Action: "click_settings_menu"},
		{Action: "dump_layout"},
		{Action: "teardown"},
	}
	return nil
}
```
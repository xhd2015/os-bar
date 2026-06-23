# Scenario

**Feature**: normal launch does not auto-open Integrations window

```
# app starts as menu-bar-only; no settings window on bootstrap
launch_app -> daemon ready -> check_window (no Integrations visible)
```

## Steps
1. Run sequence: `launch_app` → `check_window` → `teardown`.
2. Inspect `resp.WindowVisible` and `resp.WindowOpen` without layout dump.

## Context
- Validates R1: bootstrap must not show Integrations window on normal launch.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "sequence"
	req.Sequence = []Request{
		{Action: "launch_app"},
		{Action: "check_window", WaitMs: 2000},
		{Action: "teardown"},
	}
	return nil
}
```
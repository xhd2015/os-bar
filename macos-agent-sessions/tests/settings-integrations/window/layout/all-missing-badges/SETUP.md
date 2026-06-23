# Scenario

## Steps
1. Run sequence: `open_settings` → `dump_layout` → `teardown` with empty `fakeHome`.
2. Inspect status badge and install button nodes per integration row.

## Context
- All four rows should show status title `Missing` and an install button (`AXButton`).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "sequence"
	req.Sequence = []Request{
		{Action: "open_settings"},
		{Action: "dump_layout"},
		{Action: "teardown"},
	}
	return nil
}
```
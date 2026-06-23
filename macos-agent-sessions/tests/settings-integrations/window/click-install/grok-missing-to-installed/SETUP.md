# Scenario

## Steps
1. Start with empty `fakeHome` (all integrations missing).
2. Run sequence: `open_settings` → `dump_layout` → click `integration-grok-install` → wait 500ms → `dump_layout` → `teardown`.

## Context
- Before click: `integration-grok-status` title is `Missing`, install button present.
- After click: status becomes `Up to date`, install button absent.
- Side effect: `fakeHome/.grok/hooks/agent-sessions.json` created.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "sequence"
	req.WaitMs = 500
	req.Sequence = []Request{
		{Action: "open_settings"},
		{Action: "dump_layout"},
		{Action: "click", Identifier: "integration-grok-install"},
		{Action: "dump_layout", WaitMs: 500},
		{Action: "teardown"},
	}
	return nil
}
```
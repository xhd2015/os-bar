## Steps
1. Start with empty `fakeHome` (all integrations missing).
2. Run sequence: `open_settings` → `dump_layout` → click `integration-opencode-install` → wait 500ms → `dump_layout` → `teardown`.

## Context
- Same transition pattern as grok, targeting OpenCode global plugin path.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "sequence"
	req.WaitMs = 500
	req.Sequence = []Request{
		{Action: "open_settings"},
		{Action: "dump_layout"},
		{Action: "click", Identifier: "integration-opencode-install"},
		{Action: "dump_layout", WaitMs: 500},
		{Action: "teardown"},
	}
	return nil
}
```
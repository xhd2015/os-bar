# Scenario

## Preconditions
- No pre-existing `hooks.json` before install (`PreExistingHooksJSON` is empty).

## Steps
- Grouping node for fresh codex installs.

## Context
- Validates install behavior when hooks.json does not exist yet.

```go
func Setup(t *testing.T, req *Request) error {
	req.PreExistingHooksJSON = ""
	t.Logf("codex/empty-hooks: no pre-existing hooks.json")
	return nil
}
```
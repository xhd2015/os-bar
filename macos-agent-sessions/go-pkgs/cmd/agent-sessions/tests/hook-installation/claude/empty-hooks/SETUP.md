# Scenario

## Preconditions
- No pre-existing `settings.json` before install (`PreExistingHooksJSON` is empty).

## Steps
- Grouping node for fresh claude installs.

## Context
- Validates install behavior when settings.json does not exist yet.

```go
func Setup(t *testing.T, req *Request) error {
	req.PreExistingHooksJSON = ""
	t.Logf("claude/empty-hooks: no pre-existing settings.json")
	return nil
}
```

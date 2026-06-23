# Scenario

## Steps
1. Set `PreExistingHooksJSON` to invalid JSON `{not json`.
2. Call `Run(t, req)` with local codex install.

## Context
- Malformed pre-existing hooks.json should produce a merge error without corrupting the file.

```go
func Setup(t *testing.T, req *Request) error {
	req.PreExistingHooksJSON = "{not json"
	req.Target = "codex"
	req.Global = false
	return nil
}
```
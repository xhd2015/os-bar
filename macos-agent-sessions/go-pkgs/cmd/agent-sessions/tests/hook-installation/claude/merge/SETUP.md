# Scenario

## Preconditions
- Tests pre-seed `settings.json` before install via `PreExistingHooksJSON`.
- Fixtures live in `testdata/` at the suite root.

## Steps
- Grouping node. Leaves load fixtures or inline malformed JSON into `PreExistingHooksJSON`.

## Context
- `MergeClaudeHooks` must preserve all top-level keys (`permissions`, `env`, `model`, …)
  and third-party hooks, and upsert only our `Stop` handler (identified by statusMessage).

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "claude"
	req.Global = false
	t.Logf("claude/merge: pre-seeded settings.json")
	return nil
}
```

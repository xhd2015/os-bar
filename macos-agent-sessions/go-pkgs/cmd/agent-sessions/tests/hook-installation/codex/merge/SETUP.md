# Scenario

## Preconditions
- Tests pre-seed `hooks.json` before install via `PreExistingHooksJSON`.
- Fixtures live in `testdata/` at the suite root.

## Steps
- Grouping node. Leaves load fixtures or inline malformed JSON into `PreExistingHooksJSON`.

## Context
- `mergeCodexHooks` must preserve third-party hooks and upsert only our statusMessage entries.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "codex"
	req.Global = false
	t.Logf("codex/merge: pre-seeded hooks.json")
	return nil
}
```
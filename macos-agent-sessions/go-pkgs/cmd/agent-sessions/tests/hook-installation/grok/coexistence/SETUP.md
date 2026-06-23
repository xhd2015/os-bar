# Scenario

## Preconditions
- Grok loads multiple `*.json` files from `.grok/hooks/` at runtime; install writes only `agent-sessions.json`.

## Steps
- Grouping node for coexistence tests: pre-seed a foreign hook file, run install, assert foreign file unchanged.

## Context
- Unlike codex, grok install does not merge JSON — it adds a dedicated file alongside existing hook files.

```go
func Setup(t *testing.T, req *Request) error {
	req.Target = "grok"
	t.Logf("grok/coexistence: foreign hook file must survive install")
	return nil
}
```
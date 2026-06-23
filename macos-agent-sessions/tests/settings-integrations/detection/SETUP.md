# Scenario

## Preconditions
- Detection tests run `agent-sessions integrations --json` only — no UI, no Accessibility permission required.
- v1 scope is global: all detection leaves use `--global`.

## Steps
1. Set `req.Action = "integrations_json"` and `req.Global = true`.
2. Apply leaf-specific `req.SeedProfile` via child `Setup`.
3. Call `Run(t, req)` and assert on `resp.Integrations`.

## Context
- Always returns exactly four integrations: grok, opencode, pi, codex.
- Paths must resolve under isolated `fakeHome`, never the real user home.
- Status values: `missing`, `installed`, `up_to_date`, `outdated`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionIntegrationsJSON
	req.Global = true
	return nil
}
```
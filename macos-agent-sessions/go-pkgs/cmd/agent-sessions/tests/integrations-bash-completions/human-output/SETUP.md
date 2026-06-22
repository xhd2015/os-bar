# Scenario

**Feature**: integrations dual-scope human-readable output

```
# default lists both scopes with bare header
test -> agent-sessions integrations -> Integrations: dual-scope table

# single-scope filters use scoped headers without row suffixes
test -> agent-sessions integrations --global -> Integrations (global): table
test -> agent-sessions integrations --local -> Integrations (local): table

# both flags same as default
test -> agent-sessions integrations --global --local -> Integrations: dual-scope table

# JSON entry count follows scope flags
test -> agent-sessions integrations --json -> 8 entries (global+local)
test -> agent-sessions integrations --json --local -> 4 local entries
```

## Preconditions

- `integrations` without `--json` must not error with `--json is required`.
- Human output uses scope-aware headers, agent order grok/opencode/pi/codex, and macOS UI status labels.
- Dual-scope mode adds `(Global)` / `(Local)` suffixes when rows are not collapsed.

## Steps

- Grouping node. Sets `req.Action = "integrations"`. Leaves set `JsonOut`, `Global`, `Local`, and optional seed flags.

## Context

- Integration order: grok, opencode, pi, codex.
- Human status labels: `missing` → `Missing`, `up_to_date` → `Up to date`, `outdated` → `Outdated`.
- Empty `fakeHome` + empty `workDir` with default flags yields eight `Missing` rows (global then local per agent).
- Same non-missing status in both scopes collapses to one row with `(Global + Local)` suffix.
- `json-still-works` leaf sets `JsonOut = true`, `Global = true` (4-entry JSON regression).

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations"
	t.Logf("human-output: preparing integrations listing scenario")
	return nil
}
```
# Scenario

**Feature**: all integrations missing in global scope

```
# empty fakeHome + --global -> every row shows Missing
test -> agent-sessions integrations --global -> 4x Missing labels
```

## Steps

1. Set `Global = true`, `JsonOut = false`.
2. Rely on empty `fakeHome` (no pre-seeded integration files).

## Context

- Confirms human label mapping for the `missing` JSON status.

```go
func Setup(t *testing.T, req *Request) error {
	req.JsonOut = false
	req.Global = true
	return nil
}
```
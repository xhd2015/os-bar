# Scenario

**Feature**: integrations grok --install dry-run smoke

```
# dry-run reports install without writes
agent-sessions integrations grok --install --dry-run -> install report stdout
```

## Steps

- Grouping node for grok install smoke tests.

## Context

- Dry-run must report pending install but create no files.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("grok/install: narrowing grok install scenario")
	return nil
}
```
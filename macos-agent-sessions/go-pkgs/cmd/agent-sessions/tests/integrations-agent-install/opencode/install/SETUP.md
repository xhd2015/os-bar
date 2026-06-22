# Scenario

**Feature**: integrations opencode --install dry-run smoke

```
# dry-run reports install without writes
agent-sessions integrations opencode --install --dry-run -> opencode plugin install report
```

## Steps

- Grouping node for opencode install smoke tests.

## Context

- Dry-run stdout uses label `opencode plugin` with `install →`.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("opencode/install: narrowing opencode install scenario")
	return nil
}
```
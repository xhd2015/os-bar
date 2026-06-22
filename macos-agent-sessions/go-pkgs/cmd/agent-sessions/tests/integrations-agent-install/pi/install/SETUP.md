# Scenario

**Feature**: integrations pi --install dry-run smoke

```
# dry-run reports install without writes
agent-sessions integrations pi --install --dry-run -> pi extension install report
```

## Steps

- Grouping node for pi install smoke tests.

## Context

- Dry-run stdout uses label `pi extension` with `install →`.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("pi/install: narrowing pi install scenario")
	return nil
}
```
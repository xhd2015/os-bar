# Scenario

**Feature**: integrations --json --global unchanged after agent subcommands

```
# flag-only integrations JSON listing
agent-sessions integrations --json --global -> JSON integrations list
```

## Steps

1. Set `Action = "integrations"`, `JsonOut = true`, `Global = true`.

## Context

- Response must be valid JSON with exactly five integration entries.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations"
	req.JsonOut = true
	req.Global = true
	return nil
}
```
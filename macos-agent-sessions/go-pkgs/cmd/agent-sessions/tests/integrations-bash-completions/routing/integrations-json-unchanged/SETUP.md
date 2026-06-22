# Scenario

**Feature**: integrations --json --global unchanged

```
test -> agent-sessions integrations --json --global -> 4 integrations JSON
```

## Steps

1. Set `Global = true`.

## Context

- All four integration IDs must be present in the JSON envelope.

```go
func Setup(t *testing.T, req *Request) error {
	req.Global = true
	return nil
}
```
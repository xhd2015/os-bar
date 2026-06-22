# Scenario

**Feature**: integrations --help includes generic agent install example

```
# top-level integrations help
test -> agent-sessions integrations --help -> Examples section with agent install line
```

## Steps

1. Set `Action = "integrations"` and `Args = ["--help"]`.

## Context

- Expected examples must include a generic agent install line such as `agent-sessions integrations codex --install`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations"
	req.Args = []string{"--help"}
	return nil
}
```
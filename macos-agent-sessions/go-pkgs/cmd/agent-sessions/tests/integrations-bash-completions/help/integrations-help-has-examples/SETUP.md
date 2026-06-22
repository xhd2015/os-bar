# Scenario

**Feature**: integrations --help includes Examples block

```
# top-level integrations help
test -> agent-sessions integrations --help -> Examples section on stdout
```

## Steps

1. Set `Action = "integrations"` and `Args = ["--help"]`.

## Context

- Expected examples cover bare integrations, scope filters (`--global`, `--local`), JSON listing, and bash-completions install.
- Flags must describe dual-scope default, `--local`, and `--json` as machine-readable.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "integrations"
	req.Args = []string{"--help"}
	return nil
}
```
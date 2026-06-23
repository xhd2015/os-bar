# Scenario

## Preconditions
- Tests in this subtree validate CLI argument requirements for `agent-sessions install`.

## Steps
- Grouping node. Leaves run `install` without a target flag.

## Context
- `cmdInstall` requires at least one of `--pi`, `--opencode`, `--grok`, or `--codex`.
- Missing flags produce exit code 1 and a stderr message.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = ""
	t.Logf("validation: install without target flag")
	return nil
}
```
# Scenario

## Preconditions
- Tests in this subtree install grok Stop notification hooks (`agent-sessions.json` + `bin/agent-sessions-stop.sh`).

## Steps
- Grouping node. Each leaf sets `req.Target = "grok"` and varies Global/DryRun/RunTwice.

## Context
- Local paths: `<workDir>/.grok/hooks/agent-sessions.json` and `bin/agent-sessions-stop.sh`.
- Global paths: `<fakeHome>/.grok/hooks/...`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = "grok"
	t.Logf("grok: preparing install test")
	return nil
}
```
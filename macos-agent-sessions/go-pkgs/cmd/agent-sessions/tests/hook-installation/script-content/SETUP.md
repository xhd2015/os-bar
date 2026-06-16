## Preconditions
- Tests verify bundled hook script content after installation.

## Steps
- Grouping node. Uses grok install to place `agent-sessions-stop.sh` on disk.

## Context
- The stop script implements a jq → python3 → node → grep fallback chain for JSON field extraction.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "install"
	req.Target = "grok"
	t.Logf("script-content: verifying hook script markers")
	return nil
}
```
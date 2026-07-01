# Scenario

## Steps
1. Load `testdata/claude-old-agent-sessions.json` into `PreExistingHooksJSON`.
2. Call `Run(t, req)` with local claude install.

## Context
- Pre-seeded file has our statusMessage with stale command path `/old/path.sh`.
- After install: exactly 1 our Stop entry, command path updated to `AGENT_SESSIONS_AGENT=claude '<script>'`.

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	fixture := filepath.Join(DOCTEST_ROOT, "testdata", "claude-old-agent-sessions.json")
	data, err := os.ReadFile(fixture)
	if err != nil {
		return err
	}
	req.PreExistingHooksJSON = string(data)
	req.Target = "claude"
	req.Global = false
	return nil
}
```

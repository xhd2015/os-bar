# Scenario

## Steps
1. Load `testdata/codex-old-agent-sessions.json` into `PreExistingHooksJSON`.
2. Call `Run(t, req)` with local codex install.

## Context
- Pre-seeded file has our statusMessage with stale command path `/old/path.sh`.
- After install: exactly 1 our Stop entry, command path updated to real script path.

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	fixture := filepath.Join(DOCTEST_ROOT, "testdata", "codex-old-agent-sessions.json")
	data, err := os.ReadFile(fixture)
	if err != nil {
		return err
	}
	req.PreExistingHooksJSON = string(data)
	req.Target = "codex"
	req.Global = false
	return nil
}
```
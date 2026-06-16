## Steps
1. Load `testdata/grok-foreign-hooks.json` into `PreExistingGrokHooksJSON` as `other-hooks.json`.
2. Call `Run(t, req)` with `Target: "grok"`, local install.

## Context
- Pre-seeded `other-hooks.json` has a foreign `SessionStart` hook.
- After install: foreign file byte-identical; our `agent-sessions.json` and stop script also exist.

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	fixture := filepath.Join(DOCTEST_ROOT, "testdata", "grok-foreign-hooks.json")
	data, err := os.ReadFile(fixture)
	if err != nil {
		return err
	}
	req.PreExistingGrokHookFile = "other-hooks.json"
	req.PreExistingGrokHooksJSON = string(data)
	req.Target = "grok"
	req.Global = false
	return nil
}
```
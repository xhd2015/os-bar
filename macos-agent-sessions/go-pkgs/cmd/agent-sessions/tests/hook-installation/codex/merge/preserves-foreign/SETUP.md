# Scenario

## Steps
1. Load `testdata/codex-foreign-hooks.json` into `PreExistingHooksJSON`.
2. Call `Run(t, req)` with `Target: "codex"`, local install.

## Context
- Pre-seeded file has `UserPromptSubmit` and a foreign `Stop` (`statusMessage: "skynet stop"`).
- After install: both preserved, our Stop appended (2 Stop groups total).

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	fixture := filepath.Join(DOCTEST_ROOT, "testdata", "codex-foreign-hooks.json")
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
# Scenario

## Steps
1. Load `testdata/claude-foreign-settings.json` into `PreExistingHooksJSON`.
2. Call `Run(t, req)` with `Target: "claude"`, local install.

## Context
- Pre-seeded file has top-level `permissions`, `env`, `model`, a foreign `UserPromptSubmit` hook,
  and a foreign `Stop` hook (`statusMessage: "skynet stop"`, command `/bin/skynet.sh`).
- After install: top-level keys + foreign hooks intact, our Stop appended (2 Stop groups total).

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	fixture := filepath.Join(DOCTEST_ROOT, "testdata", "claude-foreign-settings.json")
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

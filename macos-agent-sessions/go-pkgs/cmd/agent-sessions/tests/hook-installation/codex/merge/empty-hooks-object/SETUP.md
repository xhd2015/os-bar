## Steps
1. Load `testdata/codex-empty.json` (`{"hooks":{}}`) into `PreExistingHooksJSON`.
2. Call `Run(t, req)` with local codex install.

## Context
- Empty hooks object should receive our Stop entry after merge.

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	fixture := filepath.Join(DOCTEST_ROOT, "testdata", "codex-empty.json")
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
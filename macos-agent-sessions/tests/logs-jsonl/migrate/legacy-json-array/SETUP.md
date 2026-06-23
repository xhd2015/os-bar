# Scenario

**Feature**: convert legacy JSON array to JSONL in place

```
# seed notify-logs.json (JSON array, 2 entries)
[{"source":"legacy","timestamp":"...","dir":"/a"}, {"source":"legacy","timestamp":"...","dir":"/b"}]

# start daemon -> migrate -> GET /api/logs
```

## Steps

1. Write `notify-logs.json` with 2-entry JSON array.
2. Do **not** create `notify-logs.jsonl` beforehand.
3. Start daemon and `GET /api/logs`.

```go
import (
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	stateDir := filepath.Join(t.TempDir(), "state")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return err
	}
	legacy := `[
  {"source":"legacy","timestamp":"2026-06-23T09:00:00Z","dir":"/a","event":"ea"},
  {"source":"legacy","timestamp":"2026-06-23T09:01:00Z","dir":"/b","event":"eb"}
]`
	legacyPath := filepath.Join(stateDir, logFileNameLegacy)
	if err := os.WriteFile(legacyPath, []byte(legacy), 0644); err != nil {
		return err
	}
	req.StateDir = stateDir
	req.Action = actionHTTPSequence
	req.Port = 0
	req.HTTPSteps = []HTTPStep{{Method: "GET", Path: "/api/logs"}}
	return nil
}
```
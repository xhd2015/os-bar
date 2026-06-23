# Scenario

**Feature**: 3-line JSONL seed loads into memory

```
# pre-seed notify-logs.jsonl
{"dir":"/one",...}\n{"dir":"/two",...}\n{"dir":"/three",...}\n

# daemon start + GET /api/logs
-> 3 entries with matching dirs
```

## Steps

1. Write 3 JSONL lines to `{stateDir}/notify-logs.jsonl` before daemon start.
2. Start daemon and `GET /api/logs`.

```go
import (
	"fmt"
	"os"
	"path/filepath"
)

func Setup(t *testing.T, req *Request) error {
	stateDir := filepath.Join(t.TempDir(), "state")
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return err
	}
	var lines []string
	for i, dir := range []string{"/one", "/two", "/three"} {
		lines = append(lines, fmt.Sprintf(
			`{"source":"test","timestamp":"2026-06-23T10:0%d:00Z","dir":%q,"event":"e%d"}`,
			i, dir, i,
		))
	}
	logPath := filepath.Join(stateDir, logFileNameJSONL)
	if err := os.WriteFile(logPath, []byte(stringsJoinLines(lines)+"\n"), 0644); err != nil {
		return err
	}
	req.StateDir = stateDir
	req.Action = actionHTTPSequence
	req.Port = 0
	req.HTTPSteps = []HTTPStep{{Method: "GET", Path: "/api/logs"}}
	return nil
}

func stringsJoinLines(lines []string) string {
	out := ""
	for i, line := range lines {
		if i > 0 {
			out += "\n"
		}
		out += line
	}
	return out
}
```
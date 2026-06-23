## Expected

- `notify-logs.jsonl` has exactly **2** non-empty lines.
- Each line is a valid JSON object.
- Full file content does **not** start with `[` (not a JSON array file).
- Lines correspond to `/proj-a` and `/proj-b`.

## Side Effects

- Append-only: line count grows by one per notify (no full-array rewrite).

## Errors

- Line count ≠ 2 or array wrapper present fails the test.

```go
import (
	"encoding/json"
	"os"
	"strings"
)

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	assertStateDirIsolated(t, resp.StateDir)

	logPath := logsJSONLPath(resp.StateDir)
	raw, readErr := os.ReadFile(logPath)
	if readErr != nil {
		t.Fatalf("read log file: %v", readErr)
	}
	content := string(raw)
	trimmed := strings.TrimSpace(content)
	if strings.HasPrefix(trimmed, "[") {
		t.Fatalf("file must not be JSON array format, got prefix `[` in %q", content)
	}

	lines := readJSONLLines(t, logPath)
	if len(lines) != 2 {
		t.Fatalf("expected 2 JSONL lines, got %d", len(lines))
	}

	dirs := make(map[string]bool)
	for _, line := range lines {
		assertValidJSONLObjectLine(t, line)
		var entry NotifyLogEntry
		if jsonErr := json.Unmarshal([]byte(line), &entry); jsonErr != nil {
			t.Fatalf("unmarshal line: %v", jsonErr)
		}
		dirs[entry.Dir] = true
	}
	if !dirs["/proj-a"] || !dirs["/proj-b"] {
		t.Fatalf("expected dirs /proj-a and /proj-b, got %v", dirs)
	}
	t.Logf("append/second-append OK: %d lines", len(lines))
}
```
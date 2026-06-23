## Expected

- `notify-logs.jsonl` exists under `resp.StateDir`.
- File contains exactly **1** non-empty line.
- Line is a valid JSON object (not a JSON array).
- Raw file content ends with `\n` (trailing newline after the line).
- Parsed line has `dir == "/proj"`.

## Side Effects

- `notify-logs.json` must **not** exist (JSONL-only going forward).

## Errors

- Missing file, zero lines, or array wrapper `[` in file content fails the test.

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
	if _, statErr := os.Stat(logPath); statErr != nil {
		t.Fatalf("expected notify-logs.jsonl to exist: %v", statErr)
	}
	if _, legacyErr := os.Stat(logsLegacyPath(resp.StateDir)); !os.IsNotExist(legacyErr) {
		t.Fatal("legacy notify-logs.json must not exist after JSONL append")
	}

	raw, readErr := os.ReadFile(logPath)
	if readErr != nil {
		t.Fatalf("read log file: %v", readErr)
	}
	content := string(raw)
	if !strings.HasSuffix(content, "\n") {
		t.Fatalf("expected trailing newline in JSONL file, got %q", content)
	}
	if strings.Contains(content, "[") {
		t.Fatalf("JSONL file must not contain array wrapper, got %q", content)
	}

	lines := readJSONLLines(t, logPath)
	if len(lines) != 1 {
		t.Fatalf("expected 1 JSONL line, got %d", len(lines))
	}
	assertValidJSONLObjectLine(t, lines[0])

	var entry NotifyLogEntry
	if jsonErr := json.Unmarshal([]byte(lines[0]), &entry); jsonErr != nil {
		t.Fatalf("unmarshal line: %v", jsonErr)
	}
	if entry.Dir != "/proj" {
		t.Fatalf("expected dir=/proj, got %q", entry.Dir)
	}
	t.Logf("append/writes-jsonl-line OK: 1 line, dir=%s", entry.Dir)
}
```
## Expected

- `notify-logs.jsonl` exists with **2** JSONL lines preserving `/a` and `/b`.
- `notify-logs.json` is **removed** (not present on disk).
- `GET /api/logs` returns 2 entries with dirs `/a` and `/b`.

## Side Effects

- One-time migration on daemon load; subsequent runs use `.jsonl` only.

## Errors

- Legacy file still present or missing `.jsonl` fails the test.

```go
import "os"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	assertStateDirIsolated(t, resp.StateDir)

	jsonlPath := logsJSONLPath(resp.StateDir)
	if _, statErr := os.Stat(jsonlPath); statErr != nil {
		t.Fatalf("expected notify-logs.jsonl after migration: %v", statErr)
	}
	if _, legacyErr := os.Stat(logsLegacyPath(resp.StateDir)); !os.IsNotExist(legacyErr) {
		t.Fatal("legacy notify-logs.json must be removed after migration")
	}

	lines := readJSONLLines(t, jsonlPath)
	if len(lines) != 2 {
		t.Fatalf("expected 2 migrated JSONL lines, got %d", len(lines))
	}
	for _, line := range lines {
		assertValidJSONLObjectLine(t, line)
	}

	if len(resp.LogEntries) != 2 {
		t.Fatalf("expected 2 API log entries, got %d", len(resp.LogEntries))
	}
	dirs := map[string]bool{}
	for _, e := range resp.LogEntries {
		dirs[e.Dir] = true
	}
	if !dirs["/a"] || !dirs["/b"] {
		t.Fatalf("expected migrated dirs /a and /b, got %v", dirs)
	}
	t.Logf("migrate/legacy-json-array OK: %d lines, legacy removed", len(lines))
}
```
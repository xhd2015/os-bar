## Expected

- `notify-logs.jsonl` has **≤ 200** non-empty lines (exactly 200 after compaction).
- No line contains `"dir":"/proj-00"` (oldest of 201 evicted).
- Some line contains `"dir":"/proj-200"` (newest retained).

## Side Effects

- Compaction rewrites tail 200 lines when over cap.

## Errors

- Line count > 200 or presence of `/proj-00` fails the test.

```go
import "strings"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	assertStateDirIsolated(t, resp.StateDir)

	lines := readJSONLLines(t, logsJSONLPath(resp.StateDir))
	if len(lines) > 200 {
		t.Fatalf("expected cap 200 lines on disk, got %d", len(lines))
	}
	if len(lines) != 200 {
		t.Fatalf("expected exactly 200 lines after 201st append, got %d", len(lines))
	}

	hasOldest := false
	hasNewest := false
	for _, line := range lines {
		if strings.Contains(line, `"/proj-00"`) {
			hasOldest = true
		}
		if strings.Contains(line, `"/proj-200"`) {
			hasNewest = true
		}
	}
	if hasOldest {
		t.Fatal("expected /proj-00 evicted (oldest of 201)")
	}
	if !hasNewest {
		t.Fatal("expected /proj-200 retained (newest)")
	}
	t.Logf("cap/truncates-at-200 OK: %d lines on disk", len(lines))
}
```
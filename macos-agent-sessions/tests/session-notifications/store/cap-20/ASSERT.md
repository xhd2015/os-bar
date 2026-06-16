## Expected
- `resp.Count == 20`.
- `len(resp.Events) == 20`.
- The first added dir (`/Users/test/project-00`) is NOT present among the remaining events.
- All later dirs (`project-01` through `project-20`) ARE present.
- `resp.Error == ""`.

## Errors
- If `count != 20`, the test fails.
- If the oldest dir (project-00) is still present, the test fails (eviction didn't work).
- If any of the newer dirs are missing, the test fails (wrong event evicted).

```go
import "slices"

func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp == nil {
		t.Fatal("expected non-nil Response")
	}
	if resp.Error != "" {
		t.Fatalf("test helper reported error: %s", resp.Error)
	}

	if resp.Count != 20 {
		t.Fatalf("cap failed: expected count=20 after adding 21 events, got count=%d", resp.Count)
	}
	if len(resp.Events) != 20 {
		t.Fatalf("cap failed: expected 20 events, got %d", len(resp.Events))
	}

	// Collect dirs from response
	dirs := make([]string, len(resp.Events))
	for i, ev := range resp.Events {
		dirs[i] = ev.Dir
	}

	// The oldest (project-00) must NOT be present
	if slices.Contains(dirs, "/Users/test/project-00") {
		t.Fatalf("cap failed: oldest event project-00 was not evicted; remaining dirs: %v", dirs)
	}

	// Newer dirs (01..20) must all be present
	for i := 1; i <= 20; i++ {
		expectedDir := fmt.Sprintf("/Users/test/project-%02d", i)
		if !slices.Contains(dirs, expectedDir) {
			t.Fatalf("cap failed: expected dir %s to be present but it was evicted; remaining: %v", expectedDir, dirs)
		}
	}

	t.Logf("cap-20 OK: 21→20, oldest (project-00) evicted")
}
```

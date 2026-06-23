## Expected

- `resp.Error == ""`.
- `len(resp.DetailLines) == 5`.
- Detail lines include **command** (`/usr/local/bin/code`), **exit code 0**, **duration 123ms**, **stdout** (`opened editor`), **stderr** (`warn: stale lock`).

## Side Effects

- No UI rendering; only formatted detail strings from `LogsEntryFormatter.formatCommandDetails`.

## Errors

- Fewer than 5 lines or missing required substrings fails the test.

```go
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
	lines := resp.DetailLines
	if len(lines) != 5 {
		t.Fatalf("expected 5 detail_lines, got %d: %v", len(lines), lines)
	}
	joined := strings.Join(lines, "\n")
	checks := []struct {
		substr string
		label  string
	}{
		{"command:", "command label"},
		{"/usr/local/bin/code", "command value"},
		{"exit code:", "exit code label"},
		{"0", "exit code value"},
		{"duration:", "duration label"},
		{"123ms", "duration value"},
		{"stdout:", "stdout label"},
		{"opened editor", "stdout value"},
		{"stderr:", "stderr label"},
		{"warn: stale lock", "stderr value"},
	}
	for _, c := range checks {
		if !strings.Contains(joined, c.substr) {
			t.Fatalf("detail_lines must contain %s (%q); got:\n%s", c.label, c.substr, joined)
		}
	}
	t.Logf("viewer/format-command-executed OK: detail_lines=%v", lines)
}
```
## Expected
- `resp.Error` is empty.
- `resp.UnconsumedCount == 1` (magic success indicator from test helper).
- `resp.Count == 234` (durationMs round-trip).
- `resp.HTTPStatus == 0` (exitCode round-trip).
- `resp.HTTPBody == ""` (stdout round-trip).
- `resp.RelativeTime == ""` (stderr round-trip).
- `resp.LogEntryJSON` contains `"command"` key and all sub-fields.

## Errors
- If `resp.Error` is non-empty, fail with the error message.
- If any decoded value doesn't match the original input, fail with a diff.

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

	// Magic success indicator from the test helper
	if resp.UnconsumedCount != 1 {
		t.Fatalf("expected unconsumed_count=1 (success indicator), got %d", resp.UnconsumedCount)
	}

	// Verify decoded values match the originals set in SETUP
	if resp.Count != 234 {
		t.Fatalf("durationMs round-trip: expected 234, got %d", resp.Count)
	}
	if resp.HTTPStatus != 0 {
		t.Fatalf("exitCode round-trip: expected 0, got %d", resp.HTTPStatus)
	}
	if resp.HTTPBody != "" {
		t.Fatalf("stdout round-trip: expected \"\", got %q", resp.HTTPBody)
	}
	if resp.RelativeTime != "" {
		t.Fatalf("stderr round-trip: expected \"\", got %q", resp.RelativeTime)
	}

	// Verify raw JSON contains expected keys
	jsonStr := resp.LogEntryJSON
	if !strings.Contains(jsonStr, `"command"`) {
		t.Fatal("encoded JSON missing 'command' key")
	}
	if !strings.Contains(jsonStr, `"exitCode"`) {
		t.Fatal("encoded JSON missing 'exitCode' key")
	}
	if !strings.Contains(jsonStr, `"stdout"`) {
		t.Fatal("encoded JSON missing 'stdout' key")
	}
	if !strings.Contains(jsonStr, `"stderr"`) {
		t.Fatal("encoded JSON missing 'stderr' key")
	}
	if !strings.Contains(jsonStr, `"durationMs"`) {
		t.Fatal("encoded JSON missing 'durationMs' key")
	}

	t.Logf("command-log-serialize OK: json length=%d, exitCode=%d, durationMs=%d",
		len(jsonStr), resp.HTTPStatus, resp.Count)
}
```

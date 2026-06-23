## Expected

- `resp.Error == ""`.
- `len(resp.DetailLines) == 5`.
- The **stdout** and **stderr** detail lines each contain `(empty)`.

## Side Effects

- No UI rendering; only formatted detail strings.

## Errors

- Missing `(empty)` on either I/O line fails the test.

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
	var stdoutLine, stderrLine string
	for _, line := range lines {
		if strings.Contains(line, "stdout:") {
			stdoutLine = line
		}
		if strings.Contains(line, "stderr:") {
			stderrLine = line
		}
	}
	if stdoutLine == "" || !strings.Contains(stdoutLine, "(empty)") {
		t.Fatalf("stdout detail line must contain (empty), got %q; lines=%v", stdoutLine, lines)
	}
	if stderrLine == "" || !strings.Contains(stderrLine, "(empty)") {
		t.Fatalf("stderr detail line must contain (empty), got %q; lines=%v", stderrLine, lines)
	}
	t.Logf("viewer/format-command-executed-empty-io OK: stdout=%q stderr=%q", stdoutLine, stderrLine)
}
```
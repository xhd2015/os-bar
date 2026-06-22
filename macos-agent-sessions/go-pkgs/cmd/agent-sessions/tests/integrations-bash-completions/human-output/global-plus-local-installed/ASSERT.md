## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains bare header `Integrations:`.
- Grok appears on exactly one row containing `Up to date (Global + Local)`.
- Grok row joins global and local paths with ` + `.
- opencode, pi, and codex each appear on two rows with `(Global)` and `(Local)` suffixes and `Missing` labels.

## Exit Code

- `0`

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 0 {
		t.Fatalf("expected exit code 0, got %d; stderr=%q stdout=%q", resp.ExitCode, resp.Stderr, resp.Stdout)
	}

	assertDualScopeHeader(t, resp.Stdout)

	grokLines := integrationLines(resp.Stdout, "grok")
	if len(grokLines) != 1 {
		t.Fatalf("expected 1 collapsed grok row, got %d: %v; stdout:\n%s", len(grokLines), grokLines, resp.Stdout)
	}
	grokLine := grokLines[0]
	if !strings.Contains(grokLine, "Up to date (Global + Local)") {
		t.Fatalf("grok row want collapsed label; line=%q", grokLine)
	}
	if !strings.Contains(grokLine, " + ") {
		t.Fatalf("grok row want paths joined by ' + '; line=%q", grokLine)
	}

	for _, id := range []string{"opencode", "pi", "codex"} {
		lines := integrationLines(resp.Stdout, id)
		if len(lines) != 2 {
			t.Fatalf("%s want 2 dual-scope rows, got %d: %v", id, len(lines), lines)
		}
		if !strings.Contains(lines[0], "Missing (Global)") {
			t.Fatalf("%s global row want Missing (Global); line=%q", id, lines[0])
		}
		if !strings.Contains(lines[1], "Missing (Local)") {
			t.Fatalf("%s local row want Missing (Local); line=%q", id, lines[1])
		}
	}

	t.Logf("human-output/global-plus-local-installed OK")
}
```
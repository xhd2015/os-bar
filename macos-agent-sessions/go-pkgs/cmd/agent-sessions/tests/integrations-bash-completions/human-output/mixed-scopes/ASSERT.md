## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains bare header `Integrations:`.
- Grok appears on two rows: `Up to date (Global)` then `Missing (Local)`.
- opencode, pi, and codex each appear on two `Missing` rows with `(Global)` and `(Local)` suffixes.

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
	if len(grokLines) != 2 {
		t.Fatalf("expected 2 grok rows, got %d: %v", len(grokLines), grokLines)
	}
	if !strings.Contains(grokLines[0], "Up to date (Global)") {
		t.Fatalf("grok global row want Up to date (Global); line=%q", grokLines[0])
	}
	if !strings.Contains(grokLines[1], "Missing (Local)") {
		t.Fatalf("grok local row want Missing (Local); line=%q", grokLines[1])
	}

	for _, id := range []string{"opencode", "pi", "codex"} {
		lines := integrationLines(resp.Stdout, id)
		if len(lines) != 2 {
			t.Fatalf("%s want 2 rows, got %d: %v", id, len(lines), lines)
		}
		if !strings.Contains(lines[0], "Missing (Global)") {
			t.Fatalf("%s global row want Missing (Global); line=%q", id, lines[0])
		}
		if !strings.Contains(lines[1], "Missing (Local)") {
			t.Fatalf("%s local row want Missing (Local); line=%q", id, lines[1])
		}
	}

	t.Logf("human-output/mixed-scopes OK")
}
```
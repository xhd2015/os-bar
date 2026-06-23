## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains bare header `Integrations:`.
- Grok appears on exactly one row: `Up to date (Local)` with the shortened local install path only (cwd-relative, not absolute `workDir`).
- opencode, pi, and codex each appear on exactly one row: `Missing (Global + Local)` with the shortened global path only (`~/...`).

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
		t.Fatalf("expected 1 grok row, got %d: %v", len(grokLines), grokLines)
	}
	if !strings.Contains(grokLines[0], "Up to date (Local)") {
		t.Fatalf("grok row want Up to date (Local); line=%q", grokLines[0])
	}
	if strings.Contains(grokLines[0], "(Global)") {
		t.Fatalf("grok row must not show Global when global missing; line=%q", grokLines[0])
	}
	assertHumanPathShortened(t, resp.Stdout, grokLines[0], integrationLocalPath(resp, "grok"), resp)

	for _, id := range []string{"opencode", "pi", "codex"} {
		assertDualScopeBothMissingAgent(t, resp.Stdout, id, resp)
	}
	assertNoAbsoluteTempPaths(t, resp.Stdout, resp)

	t.Logf("human-output/local-only-installed OK")
}
```
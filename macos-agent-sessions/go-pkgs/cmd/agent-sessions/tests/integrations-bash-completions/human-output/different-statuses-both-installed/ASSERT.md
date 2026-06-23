## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains bare header `Integrations:`.
- Grok appears on exactly two rows: `Up to date (Global)` then `Outdated (Local)` with respective shortened paths.
- opencode, pi, and codex each appear on exactly one row: `Missing (Global + Local)` with the shortened global path only.

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
		t.Fatalf("expected 2 grok rows when both scopes differ, got %d: %v", len(grokLines), grokLines)
	}
	if !strings.Contains(grokLines[0], "Up to date (Global)") {
		t.Fatalf("grok global row want Up to date (Global); line=%q", grokLines[0])
	}
	if !strings.Contains(grokLines[1], "Outdated (Local)") {
		t.Fatalf("grok local row want Outdated (Local); line=%q", grokLines[1])
	}
	assertHumanPathShortened(t, resp.Stdout, grokLines[0], integrationGlobalPath(resp, "grok"), resp)
	assertHumanPathShortened(t, resp.Stdout, grokLines[1], integrationLocalPath(resp, "grok"), resp)

	for _, id := range []string{"opencode", "pi", "codex"} {
		assertDualScopeBothMissingAgent(t, resp.Stdout, id, resp)
	}
	assertNoAbsoluteTempPaths(t, resp.Stdout, resp)

	t.Logf("human-output/different-statuses-both-installed OK")
}
```
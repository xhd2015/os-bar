## Expected

- `resp.ExitCode == 0`.
- Grok row contains `Up to date (Global + Local)` with joined shortened paths.
- Joined path uses `~/.grok/... + .grok/...` form (no absolute temp prefixes).
- Other agents show `Missing (Global + Local)` with shortened global paths only.

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

	grokLine := integrationLine(resp.Stdout, "grok")
	if grokLine == "" {
		t.Fatalf("stdout missing grok row; got:\n%s", resp.Stdout)
	}
	if !strings.Contains(grokLine, "Up to date (Global + Local)") {
		t.Fatalf("grok row want collapsed label; line=%q", grokLine)
	}
	assertJoinedHumanPaths(t, resp.Stdout, grokLine, integrationGlobalPath(resp, "grok"), integrationLocalPath(resp, "grok"), resp)

	for _, id := range []string{"opencode", "pi", "codex"} {
		assertDualScopeBothMissingAgent(t, resp.Stdout, id, resp)
	}
	assertNoAbsoluteTempPaths(t, resp.Stdout, resp)

	t.Logf("human-output/path-shortening/dual-joined-shortened OK")
}
```
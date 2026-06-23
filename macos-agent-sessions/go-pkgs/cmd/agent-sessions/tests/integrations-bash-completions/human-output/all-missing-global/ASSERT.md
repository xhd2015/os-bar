## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `Integrations (global):`.
- Each of grok, opencode, pi, codex appears on a row containing the human label `Missing`.
- Rows do not contain raw status token `missing` as the displayed label column value.

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

	assertHumanScopeHeader(t, resp.Stdout, "global")
	assertNoScopeSuffixes(t, resp.Stdout)

	want := map[string]string{
		"grok":     "Missing",
		"opencode": "Missing",
		"pi":       "Missing",
		"codex":    "Missing",
	}
	assertHumanStatusLabels(t, resp.Stdout, want)
	assertSingleScopeHumanPaths(t, resp.Stdout, resp, true)

	t.Logf("human-output/all-missing-global OK")
}
```
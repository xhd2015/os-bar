## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains `Integrations (global):`.
- Grok row contains human label `Up to date` (not `up_to_date`).
- opencode, pi, codex rows contain `Missing`.

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

	want := map[string]string{
		"grok":     "Up to date",
		"opencode": "Missing",
		"pi":       "Missing",
		"codex":    "Missing",
	}
	assertHumanStatusLabels(t, resp.Stdout, want)
	assertSingleScopeHumanPaths(t, resp.Stdout, resp, true)

	for _, line := range strings.Split(resp.Stdout, "\n") {
		if strings.Contains(line, "grok") && strings.Contains(line, "up_to_date") {
			t.Fatalf("grok row must not show raw status up_to_date; line=%q", line)
		}
	}

	t.Logf("human-output/status-labels-global OK")
}
```
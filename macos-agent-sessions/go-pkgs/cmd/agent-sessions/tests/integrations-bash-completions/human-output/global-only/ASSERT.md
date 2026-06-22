## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains header `Integrations (global):`.
- `resp.Stdout` lists four integrations in order: grok, opencode, pi, codex.
- Rows do not contain scope suffixes `(Global)`, `(Local)`, or `(Global + Local)`.
- `resp.Stdout` is not JSON.

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

	assertNoJSONOutput(t, resp.Stdout)
	assertHumanScopeHeader(t, resp.Stdout, "global")
	assertNoScopeSuffixes(t, resp.Stdout)
	assertIntegrationOrder(t, resp.Stdout)

	if n := countIntegrationLines(t, resp.Stdout); n != 4 {
		t.Fatalf("expected 4 integration rows, got %d; stdout:\n%s", n, resp.Stdout)
	}

	for _, id := range integrationOrder {
		assertLineHasHumanLabel(t, resp.Stdout, id)
	}

	t.Logf("human-output/global-only OK")
}
```
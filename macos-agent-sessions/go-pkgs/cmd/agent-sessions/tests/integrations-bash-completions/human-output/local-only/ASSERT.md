## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains header `Integrations (local):`.
- `resp.Stdout` lists exactly four integrations (grok, opencode, pi, codex) in that order.
- Rows do not contain scope suffixes `(Global)`, `(Local)`, or `(Global + Local)`.
- Each row uses a human status label.
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
	assertHumanScopeHeader(t, resp.Stdout, "local")
	assertNoScopeSuffixes(t, resp.Stdout)
	assertIntegrationOrder(t, resp.Stdout)

	if n := countIntegrationLines(t, resp.Stdout); n != 4 {
		t.Fatalf("expected 4 integration rows, got %d; stdout:\n%s", n, resp.Stdout)
	}

	for _, id := range integrationOrder {
		assertLineHasHumanLabel(t, resp.Stdout, id)
	}

	t.Logf("human-output/local-only OK")
}
```
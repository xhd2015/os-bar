## Expected

- `resp.ExitCode == 0`.
- `resp.Stderr` does not contain `--json is required`.
- `resp.Stdout` contains bare header `Integrations:` (not `Integrations (local):` or `Integrations (global):`).
- `resp.Stdout` lists four integration rows in order grok, opencode, pi, codex.
- Each row uses human label `Missing (Global + Local)` with the global install path only.
- `resp.Stdout` is not JSON.

## Side Effects

- No completion or profile files created.

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
	if strings.Contains(resp.Stderr, "--json is required") {
		t.Fatalf("stderr still requires --json: %q", resp.Stderr)
	}

	assertNoJSONOutput(t, resp.Stdout)
	assertDualScopeAllMissing(t, resp.Stdout, resp)

	if completionContent(resp.CompletionPath, resp) != "MISSING" {
		t.Fatalf("expected no completion file for integrations listing")
	}

	t.Logf("human-output/default-both-scopes OK")
}
```
## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` is valid JSON with an `integrations` array of length 8.
- Entries include both `scope: "global"` and `scope: "local"`.
- Each of grok, opencode, pi, codex appears twice (once per scope).
- `resp.Stdout` does not contain human table header `Integrations (`.

## Exit Code

- `0`

```go
func Assert(t *testing.T, req *Request, resp *Response, err error) {
	if err != nil {
		t.Fatalf("Run returned unexpected error: %v", err)
	}
	if resp.ExitCode != 0 {
		t.Fatalf("expected exit code 0, got %d; stderr=%q", resp.ExitCode, resp.Stderr)
	}

	if strings.Contains(resp.Stdout, "Integrations (") {
		t.Fatalf("JSON mode stdout must not contain human table header; got:\n%s", resp.Stdout)
	}

	assertJSONScopes(t, resp.Stdout, 8, map[string]bool{"global": true, "local": true})

	idCounts := make(map[string]int)
	out := parseIntegrationsJSON(t, resp.Stdout)
	for _, entry := range out.Integrations {
		idCounts[entry.ID]++
	}
	for _, id := range integrationOrder {
		if idCounts[id] != 2 {
			t.Fatalf("expected 2 entries for %q (global+local), got %d", id, idCounts[id])
		}
	}

	t.Logf("human-output/json-both-scopes OK")
}
```
## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` is valid JSON with an `integrations` array of length 5.
- Every entry has `scope: "local"`.
- Integration IDs include grok, opencode, pi, codex, and claude.
- `resp.Stdout` does not contain human table header.

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

	assertJSONScopes(t, resp.Stdout, 5, map[string]bool{"local": true})

	wantIDs := map[string]bool{"grok": false, "opencode": false, "pi": false, "codex": false, "claude": false}
	out := parseIntegrationsJSON(t, resp.Stdout)
	for _, entry := range out.Integrations {
		if _, ok := wantIDs[entry.ID]; ok {
			wantIDs[entry.ID] = true
		}
	}
	for id, found := range wantIDs {
		if !found {
			t.Fatalf("integrations JSON missing id %q; got %v", id, out.Integrations)
		}
	}

	t.Logf("human-output/json-local-only OK")
}
```
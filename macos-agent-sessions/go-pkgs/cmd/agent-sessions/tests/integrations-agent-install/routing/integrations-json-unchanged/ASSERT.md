## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` is valid JSON with an `integrations` array of length 5.
- Integration IDs include `grok`, `opencode`, `pi`, `codex`, and `claude`.

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

	out := parseIntegrationsJSON(t, resp.Stdout)
	if len(out.Integrations) != 5 {
		t.Fatalf("expected 5 integrations, got %d: %v", len(out.Integrations), out.Integrations)
	}

	wantIDs := map[string]bool{"grok": false, "opencode": false, "pi": false, "codex": false, "claude": false}
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

	t.Logf("integrations-json-unchanged OK: ids=%v", out.Integrations)
}
```
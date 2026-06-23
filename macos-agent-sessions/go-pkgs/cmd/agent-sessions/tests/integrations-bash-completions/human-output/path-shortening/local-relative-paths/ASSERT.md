## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains header `Integrations (local):`.
- Each integration row contains its local install path shortened as a cwd-relative path (e.g. `.grok/...`).
- `resp.Stdout` does not contain `resp.WorkDir` or macOS temp-dir prefixes.

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

	assertHumanScopeHeader(t, resp.Stdout, "local")
	assertSingleScopeHumanPaths(t, resp.Stdout, resp, false)

	for _, id := range integrationOrder {
		line := integrationLine(resp.Stdout, id)
		short := humanDisplayPath(t, resp, integrationLocalPath(resp, id))
		if strings.HasPrefix(short, "/") || strings.HasPrefix(short, "~") {
			t.Fatalf("%s row want cwd-relative path, got %q; line=%q", id, short, line)
		}
	}

	t.Logf("human-output/path-shortening/local-relative-paths OK")
}
```
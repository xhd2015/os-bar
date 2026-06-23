## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` contains header `Integrations (global):`.
- Each integration row contains its global install path shortened with a `~` prefix.
- `resp.Stdout` does not contain `resp.FakeHome` or macOS temp-dir prefixes.

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
	assertSingleScopeHumanPaths(t, resp.Stdout, resp, true)

	for _, id := range integrationOrder {
		line := integrationLine(resp.Stdout, id)
		if !strings.Contains(line, "~") {
			t.Fatalf("%s row want tilde-shortened global path; line=%q", id, line)
		}
	}

	t.Logf("human-output/path-shortening/global-tilde-paths OK")
}
```
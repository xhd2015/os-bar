## Expected

- `resp.ExitCode == 0`.
- `resp.Stdout` matches default dual-scope output: bare `Integrations:` header and five `Missing (Global + Local)` rows in agent order.

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
	assertDualScopeAllMissing(t, resp.Stdout, resp)

	t.Logf("human-output/both-flags-same-as-default OK")
}
```
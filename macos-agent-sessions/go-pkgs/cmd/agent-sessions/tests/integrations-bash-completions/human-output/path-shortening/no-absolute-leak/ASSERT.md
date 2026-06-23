## Expected

- `resp.ExitCode == 0`.
- Four `Missing (Global + Local)` rows in agent order.
- Every row path is shortened (starts with `~` for global missing paths).
- `resp.Stdout` contains none of: `resp.FakeHome`, `resp.WorkDir`, `/var/folders/`, `/private/var/folders/`.

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

	assertDualScopeAllMissing(t, resp.Stdout, resp)
	assertNoAbsoluteTempPaths(t, resp.Stdout, resp)

	for _, id := range integrationOrder {
		line := integrationLine(resp.Stdout, id)
		if !strings.Contains(line, "~") {
			t.Fatalf("%s row want tilde-shortened global path in dual-scope missing row; line=%q", id, line)
		}
	}

	t.Logf("human-output/path-shortening/no-absolute-leak OK")
}
```
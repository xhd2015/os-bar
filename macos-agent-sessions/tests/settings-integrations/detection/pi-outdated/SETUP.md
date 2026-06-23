# Scenario

## Steps
1. Seed `testdata/pi-outdated.ts` into `fakeHome/.pi/agent/extensions/agent-sessions-hook.ts`.
2. Call `Run(t, req)` with `integrations --json --global`.

## Context
- File exists but bytes differ from bundled `pi-agent-sessions-hook.ts`.
- Pi should report `outdated`; others remain `missing`.

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedProfile = "pi-outdated"
	return nil
}
```
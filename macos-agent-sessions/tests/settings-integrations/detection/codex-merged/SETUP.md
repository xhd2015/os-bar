## Steps
1. Seed merged `hooks.json` from `testdata/codex-merged-hooks.json` with foreign hooks preserved.
2. Seed matching stop script at `fakeHome/.codex/hooks/agent-sessions-stop.sh`.
3. Call `Run(t, req)` with `integrations --json --global`.

## Context
- Pre-seeded file has foreign `UserPromptSubmit` and foreign `Stop` (`skynet stop`) plus our `os-bar agent-sessions notify` handler.
- Codex should be `up_to_date` when merged content matches bundled expectation.
- Foreign hook command paths must remain in the on-disk file.

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedProfile = "codex-merged"
	return nil
}
```
# Scenario

## Steps
1. Seed bundled grok hook JSON and stop script into `fakeHome/.grok/hooks/`.
2. Call `Run(t, req)` with `integrations --json --global`.

## Context
- Seeds exact bundled content from `testdata/grok-hooks.json` and `testdata/grok-stop.sh`.
- Grok should be `up_to_date`; other three integrations remain `missing`.

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedProfile = "grok-installed"
	return nil
}
```
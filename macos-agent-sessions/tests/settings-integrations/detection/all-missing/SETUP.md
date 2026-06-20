## Steps
1. Leave `fakeHome` empty (no seed profile).
2. Call `Run(t, req)` with `integrations --json --global`.

## Context
- Baseline: no hook files exist under isolated home.
- All four integrations should report `missing`.

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedProfile = ""
	return nil
}
```
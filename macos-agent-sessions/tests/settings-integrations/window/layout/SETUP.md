# Scenario

## Steps
1. Open Integrations window and dump accessibility layout.
2. Assert per-row status badges and install buttons.

## Context
- Layout leaves validate presentation layer with empty `fakeHome` (all integrations missing).

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedProfile = ""
	t.Logf("window/layout: empty fakeHome, assert status badges and install buttons")
	return nil
}
```
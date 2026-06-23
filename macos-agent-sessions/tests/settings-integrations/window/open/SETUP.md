# Scenario

## Steps
1. Launch app with `-uiTestingOpenSettings` and capture Integrations window layout.

## Context
- Validates the test-only entry point opens the Integrations window without menu bar interaction.

```go
func Setup(t *testing.T, req *Request) error {
	req.SeedProfile = ""
	t.Logf("window/open: Integrations window via -uiTestingOpenSettings")
	return nil
}
```
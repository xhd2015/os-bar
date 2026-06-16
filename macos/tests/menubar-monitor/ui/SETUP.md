## Preconditions
- The `os-bar` app is built and running on macOS 13+.
- The menu bar is visible and not hidden by system preferences.

## Steps
- This is a manual-only test group. No automated assertions.
- Follow the verification checklists in `ui/DOCTEST.md`.

## Context
- These tests require human observation of the macOS menu bar and interaction with the app's menu.

```go
func Setup(t *testing.T, req *Request) error {
	// Manual UI tests — no automated setup needed.
	// Run these by following ui/DOCTEST.md manually.
	t.Skip("manual test — see ui/DOCTEST.md for verification steps")
	return nil
}
```

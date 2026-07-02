# Scenario

**Feature**: Settings open mode — DaemonClient config and picker UI

```
# config tests: isolated daemon + GET/POST /api/config → open_method
doctest Run(req) -> build agent-sessions -> serve -> HTTP actions

# picker tests: UI automation helper → AX dump → verify picker
doctest Run(req) -> build ui-automation-helper -> AX sequence actions
```

## Preconditions

- The `agent-sessions` CLI exists at `filepath.Join(DOCTEST_ROOT, "..", "..", "go-pkgs", "cmd", "agent-sessions")`.
- Daemon serves `GET /api/config` and `POST /api/config`.
- A Swift UI automation helper is built at `macos-agent-sessions/.build/ui-automation-helper`.
- Picker tests require `-uiTestingOpenSettings` launch arg and Accessibility permission.
- **Isolation**: All tests use temp dirs; daemon tests use ephemeral ports.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.

## Steps

1. Route by `req.Action`:
   - `get_config` — start daemon, GET /api/config, parse open_method
   - `set_config` — start daemon, POST /api/config, GET verify
   - `ax_sequence` — build and run ui-automation-helper with sequence actions
2. Return `(*Response, nil)`.

## Context

- Config open_method values: `"vscode"` (default), `"iterm2"`.
- AX picker identifier: `open-mode-picker`, row identifiers: `open-mode-option-vscode`, `open-mode-option-iterm2`.
- Picker tests are labeled `ui-automation, slow, requires-accessibility` and skip when accessibility is unavailable.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("settings-open-mode: root setup — Run() dispatches by req.Action")
	return nil
}
```
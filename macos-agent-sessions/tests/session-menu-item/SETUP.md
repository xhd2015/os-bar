# Scenario

**Feature**: session dropdown row label and hover tooltip formatting

```
# SessionEvent with full dir path
SessionEvent{dir, timestamp, consumed}

# formatter produces visible label (basename) and tooltip (full path)
doctest -> session_menu_item_state -> TestHelper.swift -> SessionMenuItemFormatter
```

## Preconditions

- Swift test helper is built from `os-bar-agent-sessionsTests/TestHelper.swift`.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.
- No UI rendering; pure string formatting only.

## Steps

1. Dispatch `req.Action = session_menu_item_state` in root `Run(t, req)`.
2. Leaf `Setup` sets `dir`, `consumed`, and optional fixed timestamps for relative time.
3. Leaf `Assert` validates `display_label` and `menu_tooltip`.

## Context

- Visible row: `● ` or `  ` + basename (22-char pad) + relative time.
- Tooltip: raw absolute `dir` (Option A from brainstorm).
- Basename display unchanged from current `MenuBarDropdownContent` behavior.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("session-menu-item: root setup — Run() dispatches session_menu_item_state")
	return nil
}
```
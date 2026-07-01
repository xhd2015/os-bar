# Scenario

**Feature**: Mark All Read button label and enabled flag derived from session events

```
# SessionEvent list loaded into the store
[SessionEvent{dir, timestamp, consumed}, ...]

# TestMarkAllReadState derives button state from unconsumed count
doctest -> mark_all_read_state -> TestHelper.swift -> TestMarkAllReadState
doctest <- {button_label, button_enabled, unconsumed_count}
```

## Preconditions

- Swift test helper is built from `os-bar-agent-sessionsTests/TestHelper.swift`.
- `DOCTEST_ROOT` refers to the directory of this SETUP.md file.
- No UI rendering; pure derivation from the events list only.

## Steps

1. Dispatch `req.Action = mark_all_read_state` in root `Run(t, req)`.
2. Leaf `Setup` sets `req.EventsJSON` to a JSON array of `SessionEvent`s.
3. Leaf `Assert` validates `button_label`, `button_enabled`, and `unconsumed_count`.

## Context

- Label is the constant `"Mark All Read"` regardless of state.
- Enabled is `unconsumedCount > 0`; the empty state (all consumed) is disabled.
- `unconsumed_count` = number of events with `consumed == false`.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("mark-all-read: root setup — Run() dispatches mark_all_read_state")
	return nil
}
```

# Scenario

**Feature**: Mark All Read button enabled/label vs unconsumed event count

```
# events with mixed consumed state feed the button-state derivation
[SessionEvent{consumed:true|false}, ...]

# unconsumedCount drives enabled; label is constant
TestMarkAllReadState(events) -> {button_label="Mark All Read", button_enabled=(unconsumed>0)}
```

## Steps

1. Set `req.Action = mark_all_read_state`.
2. Leaf `Setup` populates `req.EventsJSON` with the concrete event array for that case.
3. Leaf `Assert` checks `button_enabled`, `button_label`, and `unconsumed_count`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionMarkAllReadState
	return nil
}
```

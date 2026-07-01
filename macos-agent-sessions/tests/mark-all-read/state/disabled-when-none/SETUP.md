# Scenario

**Feature**: all events consumed → Mark All Read button disabled

```
# every event already consumed
[SessionEvent{dir:/a, consumed:true}, SessionEvent{dir:/b, consumed:true}]

# unconsumedCount=0 → enabled=false, label stays "Mark All Read"
TestMarkAllReadState -> {button_label:"Mark All Read", button_enabled:false, unconsumed_count:0}
```

## Steps

1. Set `req.EventsJSON` to an array where every event has `consumed=true`.
2. Call `mark_all_read_state`.

```go
func Setup(t *testing.T, req *Request) error {
	// Two events, both already consumed → unconsumedCount = 0.
	req.EventsJSON = `[
		{"id":"e1","dir":"/a","timestamp":"2026-07-01T10:00:00Z","consumed":true},
		{"id":"e2","dir":"/b","timestamp":"2026-07-01T10:05:00Z","consumed":true}
	]`
	return nil
}
```

# Scenario

**Feature**: ≥1 unconsumed event → Mark All Read button enabled

```
# mixed state with at least one unconsumed event
[SessionEvent{dir:/a, consumed:true}, SessionEvent{dir:/b, consumed:false}]

# unconsumedCount=1 → enabled=true, label stays "Mark All Read"
TestMarkAllReadState -> {button_label:"Mark All Read", button_enabled:true, unconsumed_count:1}
```

## Steps

1. Set `req.EventsJSON` to an array with at least one `consumed=false` event.
2. Call `mark_all_read_state`.

```go
func Setup(t *testing.T, req *Request) error {
	// Two events, one consumed and one unconsumed → unconsumedCount = 1.
	req.EventsJSON = `[
		{"id":"e1","dir":"/a","timestamp":"2026-07-01T10:00:00Z","consumed":true},
		{"id":"e2","dir":"/b","timestamp":"2026-07-01T10:05:00Z","consumed":false}
	]`
	return nil
}
```

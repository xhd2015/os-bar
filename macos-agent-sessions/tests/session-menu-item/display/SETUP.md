# Scenario

**Feature**: visible dropdown row uses basename, not full path

```
# event with nested absolute dir
SessionEvent.dir = "/Users/me/a/b/c/project"

# display label shows basename "project" and relative time
SessionMenuItemFormatter.displayLabel(...) -> "● project... 5m ago"
```

## Steps

1. Set `req.Dir` and `req.Consumed`.
2. Optionally fix `timestamp_iso` / `reference_iso` for stable relative time.
3. Call `session_menu_item_state`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionSessionMenuItemState
	return nil
}
```
# Scenario

**Feature**: hover tooltip shows full absolute project path

```
# event dir is absolute filesystem path
SessionEvent.dir = "/Users/me/work/my-app"

# tooltip returns same absolute path (not basename)
SessionMenuItemFormatter.tooltip(dir) -> "/Users/me/work/my-app"
```

## Steps

1. Set `req.Dir` to a known absolute path.
2. Call `session_menu_item_state` via Swift test helper.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionSessionMenuItemState
	return nil
}
```
# Scenario

**Feature**: unconsumed event shows bullet prefix

```
# unconsumed session
consumed=false -> display_label starts with "● "
```

## Steps

1. Set `req.Consumed = false`.
2. Call `session_menu_item_state`.

```go
func Setup(t *testing.T, req *Request) error {
	consumed := false
	req.Dir = "/Users/me/work/my-app"
	req.Consumed = &consumed
	req.TimestampISO = "2026-06-23T11:59:00Z"
	req.ReferenceISO = "2026-06-23T12:00:00Z"
	return nil
}
```
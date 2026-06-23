# Scenario

**Feature**: tooltip equals input dir exactly

```
# deep project path
dir = "/Users/me/work/my-app"

# tooltip mirrors dir byte-for-byte
menu_tooltip == dir
```

## Steps

1. Set `req.Dir = "/Users/me/work/my-app"`.
2. Set `req.Consumed` false (default row).
3. Call `session_menu_item_state`.

```go
func Setup(t *testing.T, req *Request) error {
	consumed := false
	req.Dir = "/Users/me/work/my-app"
	req.Consumed = &consumed
	return nil
}
```
# Scenario

**Feature**: display label contains basename but not full path

```
# deeply nested dir
dir = "/Users/me/a/b/c/my-app"

# row text includes "my-app", excludes "/Users/me/a/b/c/my-app"
```

## Steps

1. Set `req.Dir` to nested path with basename `my-app`.
2. Set fixed timestamps for deterministic relative time.

```go
func Setup(t *testing.T, req *Request) error {
	consumed := false
	req.Dir = "/Users/me/a/b/c/my-app"
	req.Consumed = &consumed
	req.TimestampISO = "2026-06-23T11:55:00Z"
	req.ReferenceISO = "2026-06-23T12:00:00Z"
	return nil
}
```
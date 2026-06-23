# Scenario

**Feature**: subtitle uses tilde-shortened home-relative parent path

```
# home=/Users/me, dir=/Users/me/Projects/foo -> body="foo", subtitle="~/Projects"
notification_content(dir, home) -> body, subtitle
```

## Steps

1. Set `dir` to `/Users/me/Projects/foo` and `home` to `/Users/me`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Dir = "/Users/me/Projects/foo"
	req.Home = "/Users/me"
	return nil
}
```
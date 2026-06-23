# Scenario

**Feature**: notification body is basename of project dir

```
# dir=/Users/me/work/my-app -> title="Agent session finished", body="my-app"
notification_content(dir) -> title, body
```

## Steps

1. Set `dir` to `/Users/me/work/my-app`.
2. Call `notification_content` without home/cwd overrides.

```go
func Setup(t *testing.T, req *Request) error {
	req.Dir = "/Users/me/work/my-app"
	return nil
}
```
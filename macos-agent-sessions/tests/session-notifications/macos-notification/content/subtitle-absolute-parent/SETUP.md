# Scenario

**Feature**: subtitle falls back to absolute parent when outside home and cwd

```
# dir=/opt/projects/my-app (no home/cwd overlap) -> subtitle="/opt/projects"
notification_content(dir) -> subtitle absolute parent path
```

## Steps

1. Set `dir` to `/opt/projects/my-app` without home/cwd that contain the path.

```go
func Setup(t *testing.T, req *Request) error {
	req.Dir = "/opt/projects/my-app"
	req.Home = "/Users/me"
	req.CWD = "/Users/me/work"
	return nil
}
```
# Scenario

**Feature**: subtitle uses cwd-relative parent when dir is under cwd

```
# cwd=/work, dir=/work/a/b -> body="b", subtitle="a"
notification_content(dir, cwd) -> body, subtitle
```

## Steps

1. Set `dir` to `/work/a/b` and `cwd` to `/work`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Dir = "/work/a/b"
	req.CWD = "/work"
	return nil
}
```
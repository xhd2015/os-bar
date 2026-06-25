# Scenario

**Feature**: notification click opens directory and marks event consumed

```
# simulate click with userInfo dir=/proj/x
notification_click(/proj/x) -> app_activated=true, window_opened=false, executed_command, opened_dir, consumed_dir
```

## Steps

1. Set `dir` to `/proj/x`.
2. Call `notification_click`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_click"
	req.Dir = "/proj/x"
	return nil
}
```
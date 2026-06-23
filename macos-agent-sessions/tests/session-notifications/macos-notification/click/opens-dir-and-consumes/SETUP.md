# Scenario

**Feature**: notification click opens directory and marks event consumed

```
# simulate click with userInfo dir=/proj/x
notification_click(/proj/x) -> opened_dir=/proj/x, consumed_dir=/proj/x
```

## Steps

1. Set `dir` to `/proj/x`.
2. Call `notification_click`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Dir = "/proj/x"
	return nil
}
```
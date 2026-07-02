# Scenario

**Feature**: `POST /api/open-dir {dir:"/tmp", open_method:"xxx"}` → HTTP 400 error

## Steps

1. Start daemon.
2. Send `POST /api/open-dir {"dir":"/tmp", "open_method":"xxx"}`.
3. Assert HTTP 400.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionOpenDir
	req.Dir = "/tmp"
	req.OpenMethod = "xxx"
	return nil
}
```
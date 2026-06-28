# Scenario

**Feature**: notification click succeeds via kool IPC without code fallback

```
# kool resolvable + ipc_handled true
notification_kool_open(/proj/b) -> open_method=kool_ipc, code_executed=false
```

## Steps

1. Simulate kool at `/usr/local/bin/kool` with IPC handled.
2. Invoke `notification_kool_open` for `/proj/b`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_kool_open"
	req.Dir = "/proj/b"
	req.KoolPresentPaths = []string{"/usr/local/bin/kool"}
	req.KoolIPCHandled = true
	return nil
}
```
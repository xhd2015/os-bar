# Scenario

**Feature**: notification falls back to code CLI when kool IPC not handled

```
# kool runs but ipc_handled false -> code <dir>
notification_kool_open -> open_method=code_cli, fallbackReason=kool_ipc_not_handled
```

## Steps

1. Present kool at `/usr/local/bin/kool`.
2. Simulate `kool_ipc_handled=false`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_kool_open"
	req.Dir = "/proj/b"
	req.KoolPresentPaths = []string{"/usr/local/bin/kool"}
	req.KoolIPCHandled = false
	return nil
}
```
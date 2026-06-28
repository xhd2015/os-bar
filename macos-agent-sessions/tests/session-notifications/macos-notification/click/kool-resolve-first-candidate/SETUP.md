# Scenario

**Feature**: kool binary resolves to first existing fixed candidate path

```
# /usr/bin/kool and /usr/local/bin/kool both "present" -> use /usr/bin/kool
notification_kool_open -> resolved_kool_bin=/usr/bin/kool
```

## Steps

1. Mark both `/usr/bin/kool` and `/usr/local/bin/kool` as present (simulator file-exists list).
2. Kool IPC handled so command uses resolved path.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_kool_open"
	req.Dir = "/proj/b"
	req.KoolPresentPaths = []string{"/usr/bin/kool", "/usr/local/bin/kool"}
	req.KoolIPCHandled = true
	return nil
}
```
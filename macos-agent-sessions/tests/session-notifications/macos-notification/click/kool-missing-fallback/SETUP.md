# Scenario

**Feature**: notification skips kool when no candidate binary exists

```
# no file at fixed candidate paths -> code CLI directly
notification_kool_open -> kool_attempted=false, fallbackReason=kool_missing
```

## Steps

1. Leave `kool_present_paths` empty (no candidate exists).
2. Invoke notification open for `/proj/b`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_kool_open"
	req.Dir = "/proj/b"
	req.KoolPresentPaths = nil
	return nil
}
```
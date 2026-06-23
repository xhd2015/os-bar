# Scenario

**Feature**: quit target prefers spawned daemon over pid file

```
# spawned child tracked by app
spawnedPID=1234, running=true

# pid file also present but ignored when spawn is running
daemon.pid -> 5678
```

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonQuitPlan
	return nil
}
```
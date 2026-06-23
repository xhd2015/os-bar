# Scenario

**Feature**: UI automation launch must not terminate daemon on quit

```
# launch argument for settings UI tests
-uiTestingOpenSettings -> shouldTerminateOnQuit=false
```

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionDaemonQuitShouldTerminate
	req.LaunchArguments = []string{"-uiTestingOpenSettings"}
	return nil
}
```
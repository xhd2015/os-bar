# Scenario

**Feature**: AGENT_SESSIONS_STATE_DIR overrides default

```go
func Setup(t *testing.T, req *Request) error {
	req.StateDirEnvValue = "/tmp/custom-agent-sessions"
	return nil
}
```
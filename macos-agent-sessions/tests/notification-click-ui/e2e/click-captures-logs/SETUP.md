# Scenario

**Feature**: click session notification and capture VS Code related logs

```
# POST notify for workDir -> wait for banner -> AX click -> log show + app log
notification_click_e2e -> delegate_did_receive, code_process_*, vscode_activation_*
```

## Steps

1. Set `action` to `notification_click_e2e`.
2. Set `notify_dir` to work directory basename path (absolute `workDir` from Run).
3. Set `log_capture_seconds` to 20.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_click_e2e"
	req.LogCaptureSeconds = 20
	return nil
}
```
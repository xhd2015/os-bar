# Scenario

**Feature**: notification open log entry records kool vs code open method

```
# POST notify with command.executed + openMethod fields
harness -> POST /api/notify (command block) -> notify-logs.jsonl line
```

## Steps

1. POST log-only notify with extended `command` object (notification click consolidated entry).
2. Read JSONL from disk and parse `command.openMethod`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionHTTPSequence
	req.Port = 0
	req.HTTPSteps = []HTTPStep{
		{
			Method: "POST",
			Path:   "/api/notify",
			Body: `{"dir":"/proj/b","event":"command.executed","command":{
				"command":"/usr/local/bin/kool vscode open /proj/b --ipc-only --json",
				"exitCode":0,
				"stdout":"{\"ipc_handled\":true,\"path\":\"/proj/b\"}",
				"stderr":"",
				"durationMs":12,
				"openMethod":"kool_ipc",
				"koolAttempted":true,
				"koolIpcHandled":true
			}}`,
		},
		{Method: "GET", Path: "/api/logs"},
	}
	return nil
}
```
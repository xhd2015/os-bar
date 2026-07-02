# Scenario

**Feature**: Config client tests — `get_config` and `set_config` actions against daemon

## Preconditions

- Daemon built from `go-pkgs/cmd/agent-sessions`, started with ephemeral port and temp state dir.
- No pre-existing config.json before each test.

## Steps

1. Set `req.Action = get_config` or `set_config`.
2. Root `Run()` builds binary, starts daemon, dispatches to HTTP handler.

## Context

- Invalid open_method values (`"invalid"`) → HTTP 400 error.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("config: group setup — req.Action = %s", req.Action)
	return nil
}
```
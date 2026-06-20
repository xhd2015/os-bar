# Scenario

**Feature**: install grok integration via HTTP API

```
# empty fakeHome, install grok globally
harness -> POST /api/integrations/install {"target":"grok","global":true} -> daemon

# status becomes up_to_date; hook files written
harness <- GET /api/integrations?global=1 -> grok up_to_date
fakeHome/.grok/hooks/ -> agent-sessions.json + bin/stop.sh
```

## Steps

1. POST `/api/integrations/install` with `target=grok`, `global=true`.
2. GET `/api/integrations?global=1` for updated status.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = actionIntegrationsInstall
	req.Target = "grok"
	req.Global = true
	return nil
}
```
# Scenario

**Feature**: integrations REST API mirrors CLI integrations command

```
# list reports install status under fake HOME
harness <- GET /api/integrations?global=1 -> daemon -> scan ~/.grok etc.

# install writes hook files via HTTP
harness -> POST /api/integrations/install -> daemon -> fakeHome/.grok/hooks/
```

## Preconditions

- Integrations tests set `HOME` to isolated `fakeHome` via daemon env.
- Global scope only in v1 (`global=1` query / `"global":true` body).

## Steps

1. Ensure `req.HomeDir` resolved to temp dir (never real home).
2. Leaf setups use `http_request` or `integrations_install` actions.

## Context

- Status enum: `missing`, `installed`, `up_to_date`, `outdated`.
- Four integrations: grok, opencode, pi, codex.

```go
func Setup(t *testing.T, req *Request) error {
	req.Port = 0
	req.Global = true
	return nil
}
```
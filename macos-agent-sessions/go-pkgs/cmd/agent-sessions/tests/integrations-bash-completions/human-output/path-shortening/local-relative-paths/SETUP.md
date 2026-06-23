# Scenario

**Feature**: single-scope local paths display cwd-relative

```
# --local lists only project-local install locations
test -> agent-sessions integrations --local -> Integrations (local): table

# each row path is shortened relative to workDir (e.g. .grok/...)
human formatter -> pathfmt.Short -> .foo/... on stdout
```

## Preconditions

- Empty `fakeHome` and `workDir`; no integrations installed.

## Steps

1. Set `req.Local = true` (single-scope local human table).

## Context

- All four agents are `Missing` with local paths only.
- Expected display paths are cwd-relative and must not contain `resp.WorkDir`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Local = true
	t.Logf("path-shortening/local-relative-paths: local scope, all missing")
	return nil
}
```
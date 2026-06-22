# Scenario

**Feature**: install appends source block to missing bash profile

```
# no profile file → --install creates completion and appends profile source
agent-sessions integrations bash-completions --install -> profile with source substring
```

## Steps

1. Set `Install = true` on empty fakeHome with no pre-seeded profile.

## Context

- Missing `~/.bash_profile` must be created on install with the marked source block appended.
- Stdout must report both completion install and profile update.

```go
func Setup(t *testing.T, req *Request) error {
	req.Install = true
	return nil
}
```
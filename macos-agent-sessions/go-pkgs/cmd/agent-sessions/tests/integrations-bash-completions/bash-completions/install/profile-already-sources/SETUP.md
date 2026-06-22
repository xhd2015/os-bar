# Scenario

**Feature**: install when bash profile already sources completion

```
# profile already contains source substring → completion created, profile untouched
pre-seed profile source -> agent-sessions integrations bash-completions --install -> installed
```

## Steps

1. Set `Install = true` and pre-seed profile with source substring via `PreExistingProfile`.
2. Leave completion file absent (no `PreExistingCompletion`).

## Context

- Profile detection uses substring `.config/agent-sessions/bash-completion.bash`, not exact guard wrapper match.
- Install must not append a second source block or modify existing profile bytes.

```go
const profileAlreadySources = `# user custom bash profile
export KEEP_ME=yes
[[ -f "$HOME/.config/agent-sessions/bash-completion.bash" ]] && source "$HOME/.config/agent-sessions/bash-completion.bash"
# end custom profile
`

func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.PreExistingProfile = profileAlreadySources
	return nil
}
```
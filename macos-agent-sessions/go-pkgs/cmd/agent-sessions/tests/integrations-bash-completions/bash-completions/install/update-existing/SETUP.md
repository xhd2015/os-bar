# Scenario

**Feature**: update stale bash completion file with profile already sourcing

```
# stale completion + profile already sources → --install updates completion only
pre-seed stale + profile source -> agent-sessions integrations bash-completions --install -> updated
```

## Steps

1. Set `Install = true`, `PreExistingCompletion = staleCompletionContent`.
2. Pre-seed profile with existing source line via `PreExistingProfile`.

## Context

- Stale completion content must be fully replaced by the bundled script.
- Profile must remain byte-identical because source substring is already present.

```go
const preSeededProfileWithSource = `export CUSTOM_VAR=keep-me
[[ -f "$HOME/.config/agent-sessions/bash-completion.bash" ]] && source "$HOME/.config/agent-sessions/bash-completion.bash"
`

func Setup(t *testing.T, req *Request) error {
	req.Install = true
	req.PreExistingCompletion = staleCompletionContent
	req.PreExistingProfile = preSeededProfileWithSource
	return nil
}
```
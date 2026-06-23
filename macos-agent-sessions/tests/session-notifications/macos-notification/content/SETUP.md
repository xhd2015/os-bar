# Scenario

**Feature**: notification title, body, subtitle, and userInfo formatting

```
# content builder uses dir + optional home/cwd for subtitle shortening
notification_content(dir, home?, cwd?) -> title, body, subtitle, user_info_dir
```

## Preconditions

- Title is always `Agent session finished`.
- Body is basename of `dir`.
- Subtitle is shortened parent path per pathfmt.Short semantics.

## Steps

- Each leaf sets `action: "notification_content"` with `dir` and optional `home` / `cwd`.

## Context

- `user_info_dir` must equal the absolute `dir` for click handler wiring.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_content"
	return nil
}
```
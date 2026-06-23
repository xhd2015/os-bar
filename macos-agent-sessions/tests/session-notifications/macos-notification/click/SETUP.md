# Scenario

**Feature**: notification click opens directory and marks event consumed

```
# default action click reads userInfo["dir"]
notification click userInfo -> openDir(dir) + markConsumed(dir) -> opened_dir, consumed_dir
```

## Preconditions

- Click handler mirrors menu bar item behavior without launching real `code` binary.

## Steps

- Leaf sets `action: "notification_click"` with target `dir`.

## Context

- Both `opened_dir` and `consumed_dir` must equal the clicked dir.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "notification_click"
	return nil
}
```
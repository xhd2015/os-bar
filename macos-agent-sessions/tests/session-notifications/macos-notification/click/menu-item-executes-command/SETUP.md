# Scenario

**Feature**: menu bar item click executes open command without app activation

```
# menu dropdown row click -> code <dir> + markConsumed; no NSApp.activate
menu_item_click(/proj/x) -> executed_command=/usr/local/bin/code /proj/x, app_activated=false
```

## Preconditions

- Mocked click handler mirrors `SessionClickHandler` with `.menuBar` source.
- No real `code` binary launch; no AppKit activation calls.

## Steps

1. Set `dir` to `/proj/x`.
2. Call `menu_item_click`.

```go
func Setup(t *testing.T, req *Request) error {
	req.Action = "menu_item_click"
	req.Dir = "/proj/x"
	return nil
}
```
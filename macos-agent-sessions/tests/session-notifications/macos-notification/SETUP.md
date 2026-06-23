# Scenario

**Feature**: macOS user notification diff, content, and click logic

```
# SessionStore poll produces previous/current snapshots
SessionStore.refresh() -> previous events, current events

# notification service diffs (dir, timestamp) pairs
notificationService.dirsNeedingNotification(previous, current) -> notify_dirs[]

# content builder formats title/body/subtitle + userInfo dir
notificationService.buildContent(dir, home, cwd) -> title, body, subtitle, user_info_dir

# click handler opens dir and marks consumed
notification delegate click -> openDir(dir) + markConsumed(dir)
```

## Preconditions

- Tests exercise `SessionNotificationService` logic via test helper actions, not real `UNUserNotificationCenter` posts.
- Diff compares `(dir, timestamp)` pairs; `consumed` changes alone do not trigger notification.
- Startup baseline (`is_baseline=true`) suppresses notifications for pre-existing events.

## Steps

- Grouping node: each leaf sets a specific notification action and parameters.

## Context

- Actions: `"notification_diff"`, `"notification_content"`, `"notification_click"`.
- `previous_json` and `current_json` are JSON arrays of session events.
- `home` and `cwd` optional for subtitle path shortening in content tests.

```go
func Setup(t *testing.T, req *Request) error {
	t.Logf("macos-notification: preparing notification logic test")
	return nil
}
```
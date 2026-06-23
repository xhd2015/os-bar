# Implementation Requirement: macOS Session Notifications

## Context

When `macos-agent-sessions` receives a session notify event, it currently only
updates the menu bar badge silently. We need macOS User Notifications with click-to-open.

**Tests are sealed — do not modify** any file under `tests/session-notifications/`.

Design session: `gen_c6615e34afc8afed2719b56e0417190a`

## Feature Summary

1. **`SessionNotificationService`** (new Swift file) — diff detection, notification
   content building (title/body/subtitle with path shortening), UNUserNotificationCenter
   posting with default sound, delegate for click → openDir + markConsumed.
2. **`SessionStore.refresh()`** — wire notification service; baseline skip on first poll.
3. **`AgentSessionApp`** — register notification delegate at launch.
4. **`TestHelper.swift`** — add actions: `notification_diff`, `notification_content`,
   `notification_click` (mirrors production logic).

## Confirmed Behavior

- Notify on new `(dir, timestamp)` pairs; re-notify on dedup bump.
- Skip notifications on first poll (baseline).
- Title: `Agent session finished`; body: basename; subtitle: shortened parent path.
- Path shortening mirrors `pathfmt.Short`: cwd-relative → tilde → absolute parent.
- Default notification sound (not silent).
- Click = `openDir(dir)` + `markConsumed(dir)`.
- Permission denied → silent fallback to menu-bar-only.

## Test Tree (11 leaves, all RED)

```
tests/session-notifications/macos-notification/
├── diff/ (6 leaves)
├── content/ (4 leaves)
└── click/ (1 leaf)
```

Extended Request fields: `previous_json`, `current_json`, `is_baseline`, `home`, `cwd`
Extended Response fields: `notify_dirs`, `title`, `body`, `subtitle`, `user_info_dir`,
`opened_dir`, `consumed_dir`

## Verify Commands

```sh
cd macos-agent-sessions
doctest vet ./tests/session-notifications
doctest test ./tests/session-notifications/macos-notification/...
doctest test ./tests/session-notifications
```

All 11 macos-notification tests must be GREEN. Existing session-notifications tests
must not regress.
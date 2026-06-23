# Requirement: macOS User Notifications for Session Updates

## Problem

Today, when an external tool notifies the agent-sessions daemon (`POST /api/notify`
with `source: "notify"`), the menu bar app only **silently** updates the bell badge
count on its 2-second poll (`SessionStore.refresh()` → `DaemonClient.listEvents()`).
The user must notice the badge and open the menu bar dropdown to act.

## Goal

When a **new or updated** session event arrives, also post a **macOS User
Notification** (`UserNotifications` / `UNUserNotificationCenter`). Clicking the
notification should **open that directory in VS Code** (same as clicking the menu
item) and **mark the event consumed**.

## Current Architecture (unchanged daemon/API)

```
hook/CLI → POST /api/notify → Go daemon (events.json)
                                    ↑ poll every 2s
                              SessionStore (Swift)
                                    ↓
                         menu bar badge + dropdown
```

| Component | Role |
|-----------|------|
| `go-pkgs/server/handlers.go` | `handleNotify` stores events |
| `SessionStore.swift` | Polls `/api/list`, publishes `events` |
| `AgentSessionApp.swift` | Menu bar UI; click → `openDir` + `markConsumed` |
| `AppDelegate.openDir` | Launches `/usr/local/bin/code <dir>` |

No `UserNotifications` code exists today.

## Proposed Design

### 1. New module: `SessionNotificationService`

A small, testable Swift type (new file under `os-bar-agent-sessions/`) responsible for:

| Responsibility | Detail |
|----------------|--------|
| Permission | Request `UNUserNotificationCenter` authorization on first use (`.alert`, `.sound`) |
| Diff detection | Given `previous` and `current` event snapshots, return dirs that need a notification |
| Post | Schedule `UNNotificationRequest` with `userInfo["dir"]` |
| Delegate | Implement `UNUserNotificationCenterDelegate`; on default-action click → `openDir(dir)` + `markConsumed(dir)` |

### 2. Diff rules (when to notify)

Notify when an event's `(dir, timestamp)` pair is **not present** in the previous
snapshot:

| Scenario | Notify? |
|----------|---------|
| Brand-new unconsumed dir | ✅ Yes |
| Same dir re-notified (dedup bump: timestamp changes, `consumed` → false) | ✅ Yes |
| Poll returns identical snapshot | ❌ No |
| Event marked consumed (no timestamp change) | ❌ No |
| **First poll after app launch** (baseline snapshot) | ❌ No — seed baseline, only notify on *subsequent* changes |

Rationale: avoids a burst of notifications for stale unconsumed events on startup.

### 3. Notification content (Option C)

| Field | Value | Visible? |
|-------|-------|----------|
| **Title** | `Agent session finished` | ✅ |
| **Body** | `<basename(dir)>` — last path component (e.g. `my-app`) | ✅ |
| **Subtitle** | Shortened parent path of `dir` (see rules below) | ✅ |
| **userInfo** | `{"dir": "<absolute-path>"}` — used for click handler only | ❌ |
| **identifier** | `session-<dir-hash or sanitized-dir>` — replace prior pending notification for same dir | — |
| **Sound** | Default system notification sound (not silent) | — |

**Example** (dir = `/Users/me/work/my-app`):

```
Agent session finished          ← title
my-app                          ← body (basename)
~/work                          ← subtitle (shortened parent path)
```

#### Path shortening rules (subtitle)

Mirror `pathfmt.Short` semantics (same as integrations CLI output), applied to
the **parent directory** of the project (not the basename itself):

1. If parent is under **cwd** → cwd-relative (e.g. `work`, `.grok/...`)
2. Else if parent is under **$HOME** → tilde prefix (e.g. `~/work`, `~/Projects`)
3. Else → absolute parent path (e.g. `/opt/projects`)

Never show raw `/Users/...` or `/var/folders/...` when a shorter form exists.

### 4. Click behavior

Identical to menu bar item click:

1. `AppDelegate.openDir(dir)` — launch `code <dir>`
2. `SessionStore.markConsumed(dir:)` — `POST /api/events/consume`

### 5. Integration point

`SessionStore.refresh()` after a successful fetch:

```swift
let newEvents = try await client.listEvents()
let toNotify = notificationService.dirsNeedingNotification(previous: events, current: newEvents)
events = newEvents
for dir in toNotify {
    await notificationService.postSessionFinished(dir: dir)
}
```

On first successful refresh, set baseline without posting.

### 6. Permission denied

If authorization is denied, **silently fall back** to existing menu-bar-only
behavior (no error dialog). Tests verify the fallback path does not crash.

### 7. App changes

| File | Change |
|------|--------|
| `SessionNotificationService.swift` | **New** — diff, post, delegate |
| `SessionStore.swift` | Wire notification service into `refresh()` |
| `AgentSessionApp.swift` | Register notification delegate at launch |
| `Info.plist` (bundled app) | No special entitlement needed for local notifications on macOS 13+ |

`TestHelper.swift` gains mirrored test actions (see Testing).

## Data Models

No new persistence. Reuses existing `SessionEvent`:

```swift
struct SessionEvent {
    let id: UUID
    let dir: String      // absolute path
    let timestamp: Date
    var consumed: Bool
}
```

Internal snapshot for diffing: `Set<(dir: String, timestamp: Date)>` or equivalent.

Notification payload (ephemeral, not persisted):

```swift
struct SessionNotificationPayload {
    let dir: String
    let title: String    // "Agent session finished"
    let body: String     // basename(dir)
}
```

## Test Plan (doctest tree)

New subtree under existing suite:

```
tests/session-notifications/
└── macos-notification/                  NEW grouping
    ├── SETUP.md
    ├── diff/                            DECISION: dirsNeedingNotification logic
    │   ├── new-event/                   LEAF: one new dir → notify
    │   ├── dedup-bump/                  LEAF: same dir, new timestamp → notify
    │   ├── unchanged-poll/              LEAF: identical snapshot → no notify
    │   ├── consumed-only-change/        LEAF: consumed flips, same timestamp → no notify
    │   └── baseline-skip/               LEAF: first snapshot seeds baseline → no notify
    ├── content/                         DECISION: notification text
    │   ├── basename-body/               LEAF: body = last path component
    │   ├── subtitle-home-tilde/         LEAF: ~/Projects/foo → subtitle "~/Projects"
    │   └── subtitle-cwd-relative/       LEAF: cwd=/work, dir=/work/a/b → subtitle "a"
    └── click/                           DECISION: click handler
        └── opens-dir-and-consumes/      LEAF: simulate click userInfo → openDir + consume recorded
```

Extend root `DOCTEST.md` index. Extend `TestHelper.swift` with actions:

| Action | Purpose |
|--------|---------|
| `notification_diff` | Input `previous_json` + `current_json` (+ optional `is_baseline`), return `notify_dirs[]` |
| `notification_content` | Input `dir` (+ optional `home`, `cwd`), return `title`, `body`, `subtitle`, `user_info_dir` |
| `notification_click` | Input `dir`, record that open+consume would fire (mock, no real `code` launch) |

Tests exercise **logic** without posting real `UNNotificationRequest` (not viable in CI).
Implementation must share the same diff/content functions the test helper mirrors.

### Expected outputs (examples)

**diff/new-event**

```
previous: []
current:  [{dir:"/proj/a", timestamp:T1, consumed:false}]
→ notify_dirs: ["/proj/a"]
```

**diff/dedup-bump**

```
previous: [{dir:"/proj/a", timestamp:T1, consumed:true}]
current:  [{dir:"/proj/a", timestamp:T2, consumed:false}]
→ notify_dirs: ["/proj/a"]
```

**diff/unchanged-poll**

```
previous == current → notify_dirs: []
```

**content/basename-body**

```
dir: "/Users/me/work/my-app"
→ title: "Agent session finished", body: "my-app"
```

**content/subtitle-home-tilde**

```
home: "/Users/me", dir: "/Users/me/Projects/foo"
→ body: "foo", subtitle: "~/Projects"
```

**content/subtitle-cwd-relative**

```
cwd: "/work", dir: "/work/a/b"
→ body: "b", subtitle: "a"
```

All cases: `user_info_dir` = absolute `dir` (for click handler).

**click/opens-dir-and-consumes**

```
click userInfo {dir:"/proj/x"}
→ opened_dir: "/proj/x", consumed_dir: "/proj/x"
```

## How to Run

```sh
cd macos-agent-sessions
doctest vet ./tests/session-notifications
doctest test ./tests/session-notifications/macos-notification/...
doctest test ./tests/session-notifications   # full suite, no regressions
```

## Out of Scope (v1)

- Notification sound customization
- Settings toggle to disable notifications
- Grouping multiple events into one summary notification
- Go daemon changes (notification is Swift-app-side only)
- Replacing menu bar badge (badge remains)

## Confirmed Decisions (user followup)

1. **Re-notification on dedup bump**: ✅ Yes — same dir with new timestamp triggers a new notification.
2. **Title/body/subtitle**: ✅ Option C — body = basename, subtitle = shortened parent path.
3. **Sound**: ✅ Default system notification sound (not silent).
4. **Startup baseline**: ✅ No notifications for pre-existing unconsumed events on launch; only subsequent changes.

## Approval

Reply **go ahead** to proceed to test design (Phase 2).
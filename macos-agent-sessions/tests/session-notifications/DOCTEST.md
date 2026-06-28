# Agent Session Notifications — Doc-Style Test Tree

Test suite for the `SessionStore`, `SessionServer`, and `SessionNotificationService`
components of the `macos-agent-sessions` menu bar app. Validates event storage rules
(add, dedup, prune, cap, sort, relative-time formatting), HTTP server behavior
(POST /api/notify, error responses), and macOS user-notification logic (diff
detection, notification content, click handler) without posting real
`UNNotificationRequest` objects.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **menu bar app** polls the Go **daemon** every two seconds via
`SessionStore.refresh()` → `DaemonClient.listEvents()`. Session **events** are
`{id, dir, timestamp, consumed}` records shown in the dropdown and bell badge.

The **Swift test helper** (`TestHelper.swift`) mirrors production types and
exposes JSON actions on stdin/stdout so the Go **doctest harness** can drive
store, server, and notification logic without launching the full app.

The **SessionStore** persists events locally (UserDefaults in production; in-memory
in tests) with dedup-by-dir, cap-20, prune-7-days, and consumed tracking.

The **SessionServer** accepts `POST /api/notify` with a project `dir` and stores
events; error paths return 400/404/405.

The **SessionNotificationService** (new) compares `previous` and `current` event
snapshots after each poll. When a `(dir, timestamp)` pair is new relative to the
previous snapshot—and the poll is not the **startup baseline**—it schedules a
macOS user notification. **Notification content** uses title `Agent session
finished`, body = basename(dir), subtitle = shortened parent path (cwd-relative,
tilde-home, or absolute). **Click** on the notification tries **kool** `vscode open --ipc-only --json` first,
then falls back to **`code <dir>`**; menu clicks use **code** only. Opens mark the
event consumed. **Notify logs** record `openMethod` (`kool_ipc` vs `code_cli`).

Tests exercise diff/content/click **logic** via helper actions
(`notification_diff`, `notification_content`, `notification_click`) without
posting real notifications (not viable in CI).

## Decision Tree

```
session-notifications/                   ROOT: Request{Action, Dir, ...}, Response{Events, Count, ...}
│                                                 Run() wraps Swift test helper via stdin/stdout
│
├── store/                               DECISION: component = store
│   └── [SETUP] req.Action ∈ store actions
│   │
│   ├── add-event/                       LEAF: add one event
│   ├── dedup-dir/                       LEAF: same dir twice → timestamp bumped
│   ├── dedup-trailing-slash/            LEAF: dir vs dir/ → single canonical event
│   ├── prune-old/                       LEAF: 8-day-old event pruned
│   ├── cap-20/                          LEAF: cap at 20
│   ├── sort-order/                      LEAF: newest-first order
│   ├── consumed-default/                LEAF: new event → consumed=false
│   ├── consumed-dedup/                  LEAF: dedup → consumed=false again
│   ├── consumed-mark/                   LEAF: markConsumed flips to true
│   ├── unconsumed-count/                LEAF: mixed counts correctly
│   ├── command-log-serialize/           LEAF: encode→decode round-trip
│   ├── command-log-null-omission/       LEAF: nil command omits JSON key
│   └── relative-time/                   DECISION: format verification
│       ├── sub-1m/                      LEAF: "<1m ago"
│       ├── exact-minutes/               LEAF: "Xm ago"
│       └── exact-hours/                 LEAF: "Xh ago"
│
├── server/                              DECISION: component = server
│   └── [SETUP] req.Action ∈ server actions
│   │
│   ├── post-notify/                     LEAF: valid POST /api/notify
│   ├── type-ignored/                    LEAF: type field accepted and ignored
│   ├── bad-json/                        LEAF: invalid JSON → 400
│   ├── missing-dir/                     LEAF: missing or empty dir → 400
│   ├── wrong-method/                    LEAF: GET /api/notify → 405
│   └── wrong-path/                      LEAF: POST /api/wrong → 404
│
└── macos-notification/                  DECISION: component = notification service
    └── [SETUP] req.Action ∈ notification actions
    │
    ├── diff/                            DECISION: dirsNeedingNotification logic
    │   ├── new-event/                   LEAF: one new dir → notify
    │   ├── multiple-new-events/         LEAF: two new dirs → notify both
    │   ├── dedup-bump/                  LEAF: same dir, new timestamp → notify
    │   ├── unchanged-poll/              LEAF: identical snapshot → no notify
    │   ├── consumed-only-change/          LEAF: consumed flips, same timestamp → no notify
    │   └── baseline-skip/               LEAF: first snapshot seeds baseline → no notify
    │
    ├── content/                         DECISION: notification text
    │   ├── basename-body/               LEAF: body = last path component
    │   ├── subtitle-home-tilde/         LEAF: ~/Projects/foo → subtitle "~/Projects"
    │   ├── subtitle-cwd-relative/       LEAF: cwd=/work, dir=/work/a/b → subtitle "a"
    │   └── subtitle-absolute-parent/    LEAF: dir outside home/cwd → absolute parent
    │
    └── click/                           DECISION: click source + open strategy
        ├── menu-item-executes-command/  LEAF: menu → code only, no kool
        ├── menu-unchanged-code-only/    LEAF: menu with kool on disk → still code only
        ├── opens-dir-and-consumes/      LEAF: notification → kool IPC ok → kool command
        ├── notification-focuses-target-window/ LEAF: notification + kool IPC → focus target dir
        ├── menu-notification-window-parity/    LEAF: menu code + notification kool → same focus
        ├── kool-ipc-success/            LEAF: notification kool IPC handled → kool_ipc
        ├── kool-ipc-fallback-to-code/    LEAF: kool fail → code_cli + fallbackReason
        ├── kool-missing-fallback/       LEAF: no kool binary → code_cli, kool_missing
        └── kool-resolve-first-candidate/ LEAF: /usr/bin/kool wins over later candidates
```

## Parameter Ranking (macos-notification)

| Rank | Parameter | Branches |
|------|-----------|----------|
| 1 | Operation | `notification_diff`, `notification_content`, `notification_click` |
| 2 | Diff transition | new, multiple-new, dedup-bump, unchanged, consumed-only, baseline |
| 3 | Content context | basename only, home-tilde, cwd-relative, absolute parent |
| 4 | Click source | menu_bar → code only; notification → kool IPC probe then optional code fallback |
| 5 | Kool resolution | binary missing, first candidate path, IPC handled vs not |

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `store/add-event/` | Add one event, verify count=1 and dir matches |
| 2 | `store/dedup-dir/` | Add same dir twice, count stays 1, timestamp updated |
| 2b | `store/dedup-trailing-slash/` | Dir with/without trailing slash → count 1 |
| 3 | `store/prune-old/` | Preload 8-day-old event, load prunes it, count=0 |
| 4 | `store/cap-20/` | Add 21 distinct dirs, cap at 20, oldest evicted |
| 5 | `store/sort-order/` | Add 3 events, verify newest-first ordering |
| 6 | `store/relative-time/sub-1m/` | Timestamp 30s ago → `"<1m ago"` |
| 7 | `store/relative-time/exact-minutes/` | Timestamp 5m ago → `"5m ago"` |
| 8 | `store/relative-time/exact-hours/` | Timestamp 2h ago → `"2h ago"` |
| 9 | `server/post-notify/` | POST valid JSON → 200, event in store |
| 10 | `server/type-ignored/` | POST with type field → accepted, dir stored |
| 11 | `server/bad-json/` | POST unparseable body → 400 |
| 12 | `server/missing-dir/` | POST without dir or empty dir → 400 |
| 13 | `server/wrong-method/` | GET /api/notify → 405 |
| 14 | `server/wrong-path/` | POST /api/wrong → 404 |
| 15 | `store/consumed-default/` | New event has `consumed == false` |
| 16 | `store/consumed-dedup/` | Dedup re-marks event as unconsumed |
| 17 | `store/consumed-mark/` | `markConsumed` sets `consumed = true` |
| 18 | `store/unconsumed-count/` | Mixed consumed/unconsumed → correct count |
| 19 | `store/command-log-serialize/` | Encode→decode round-trip with command fields survived |
| 20 | `store/command-log-null-omission/` | Nil command omits `"command"` JSON key |
| 21 | `macos-notification/diff/new-event/` | Empty previous + one new dir → notify |
| 22 | `macos-notification/diff/multiple-new-events/` | Two new dirs in one poll → notify both |
| 23 | `macos-notification/diff/dedup-bump/` | Same dir, new timestamp → notify |
| 24 | `macos-notification/diff/unchanged-poll/` | Identical snapshots → no notify |
| 25 | `macos-notification/diff/consumed-only-change/` | Consumed flips, same timestamp → no notify |
| 26 | `macos-notification/diff/baseline-skip/` | First poll baseline → no notify |
| 27 | `macos-notification/content/basename-body/` | Body = basename, title fixed |
| 28 | `macos-notification/content/subtitle-home-tilde/` | Home-relative parent → `~/Projects` |
| 29 | `macos-notification/content/subtitle-cwd-relative/` | Cwd-relative parent → `a` |
| 30 | `macos-notification/content/subtitle-absolute-parent/` | Outside home/cwd → absolute parent |
| 31 | `macos-notification/click/menu-item-executes-command/` | Menu click → `code` command, no app activation |
| 32 | `macos-notification/click/opens-dir-and-consumes/` | Notification click → activate app + `code` command |
| 33 | `macos-notification/click/notification-focuses-target-window/` | Notification + kool IPC → focus VS Code window for target dir |
| 34 | `macos-notification/click/menu-notification-window-parity/` | Menu (code) and notification (kool) focus same VS Code window |
| 35 | `macos-notification/click/kool-ipc-success/` | Notification kool IPC ok → `open_method=kool_ipc`, no code fallback |
| 36 | `macos-notification/click/kool-ipc-fallback-to-code/` | Kool IPC not handled → code CLI + consolidated log fields |
| 37 | `macos-notification/click/kool-missing-fallback/` | No kool candidate → code CLI, `fallbackReason=kool_missing` |
| 38 | `macos-notification/click/kool-resolve-first-candidate/` | `/usr/bin/kool` present → resolved path is first candidate |
| 39 | `macos-notification/click/menu-unchanged-code-only/` | Menu click never attempts kool even when installed |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Add single event | `add-event` | ✓ |
| Dedup by dir (bump timestamp) | `dedup-dir` | ✓ |
| Dedup trailing-slash paths | `dedup-trailing-slash` | ✓ (RED until normalized) |
| Prune events older than 7 days | `prune-old` | ✓ |
| Cap at 20, evict oldest | `cap-20` | ✓ |
| Sort newest-first | `sort-order` | ✓ |
| Relative time formats | `relative-time/*` | ✓ |
| Valid POST /api/notify | `post-notify` | ✓ |
| HTTP error paths | `server/*` | ✓ |
| Consumed flag semantics | `consumed-*` | ✓ |
| Command log JSON | `command-log-*` | ✓ |
| Notify on new (dir, timestamp) | `diff/new-event` | ✓ |
| Notify on multiple new dirs | `diff/multiple-new-events` | ✓ |
| Re-notify on dedup bump | `diff/dedup-bump` | ✓ |
| Skip identical poll | `diff/unchanged-poll` | ✓ |
| Skip consumed-only change | `diff/consumed-only-change` | ✓ |
| Startup baseline skip | `diff/baseline-skip` | ✓ |
| Notification title/body | `content/basename-body` | ✓ |
| Subtitle: tilde-home | `content/subtitle-home-tilde` | ✓ |
| Subtitle: cwd-relative | `content/subtitle-cwd-relative` | ✓ |
| Subtitle: absolute parent | `content/subtitle-absolute-parent` | ✓ |
| Click opens dir + consumes (kool IPC) | `click/opens-dir-and-consumes` | RED until kool in notification_click |
| Notification focuses target VS Code window | `click/notification-focuses-target-window` | RED until kool opener in simulator |
| Menu/notification window focus parity | `click/menu-notification-window-parity` | RED until kool opener in simulator |
| Kool IPC / fallback / missing / resolve | `click/kool-*` | RED until simulator implements kool path |
| Menu unchanged (no kool) | `click/menu-unchanged-code-only` | RED until simulator distinguishes sources |

## How to Run

```sh
# Vet test tree structure
cd macos-agent-sessions && doctest vet ./tests/session-notifications

# Run all tests (RED until SessionNotificationService + TestHelper actions exist)
cd macos-agent-sessions && doctest test ./tests/session-notifications

# Run notification subtree only
cd macos-agent-sessions && doctest test ./tests/session-notifications/macos-notification/...

# Verbose
cd macos-agent-sessions && doctest test -v ./tests/session-notifications/...
```

```go
import (
	"encoding/json"
	"fmt"
	"os/exec"
	"path/filepath"
	"testing"
)

// SessionEvent mirrors the Swift SessionEvent model.
type SessionEvent struct {
	ID        string `json:"id"`
	Dir       string `json:"dir"`
	Timestamp string `json:"timestamp"`
	Consumed  bool   `json:"consumed"`
}

// Request is passed as JSON to the Swift test helper via stdin.
type Request struct {
	Action        string   `json:"action"`
	Dir           string   `json:"dir,omitempty"`
	Dirs          []string `json:"dirs,omitempty"`
	EventsJSON    string   `json:"events_json,omitempty"`
	TimestampISO  string   `json:"timestamp_iso,omitempty"`
	ReferenceISO  string   `json:"reference_iso,omitempty"`
	HTTPMethod    string   `json:"http_method,omitempty"`
	HTTPPath      string   `json:"http_path,omitempty"`
	HTTPBody      string   `json:"http_body,omitempty"`
	ContentType   string   `json:"content_type,omitempty"`
	// --- command-log test fields ---
	LogDir        string `json:"log_dir,omitempty"`
	LogEvent      string `json:"log_event,omitempty"`
	LogCommand    string `json:"log_command,omitempty"`
	LogExitCode   int    `json:"log_exit_code,omitempty"`
	LogStdout     string `json:"log_stdout,omitempty"`
	LogStderr     string `json:"log_stderr,omitempty"`
	LogDurationMs int    `json:"log_duration_ms,omitempty"`
	// --- macos-notification test fields ---
	PreviousJSON string `json:"previous_json,omitempty"`
	CurrentJSON  string `json:"current_json,omitempty"`
	IsBaseline   bool   `json:"is_baseline,omitempty"`
	Home         string `json:"home,omitempty"`
	CWD          string `json:"cwd,omitempty"`
	// --- vscode window focus click test fields ---
	ClickSource        string   `json:"click_source,omitempty"`
	VSCodeFrontmostDir string   `json:"vscode_frontmost_dir,omitempty"`
	VSCodeOpenDirs     []string `json:"vscode_open_dirs,omitempty"`
	// --- notification kool open (TestVSCodeFocusSimulator) ---
	KoolPresentPaths []string `json:"kool_present_paths,omitempty"`
	KoolIPCHandled   bool     `json:"kool_ipc_handled,omitempty"`
	KoolIPCError     string   `json:"kool_ipc_error,omitempty"`
	KoolJSONInvalid  bool     `json:"kool_json_invalid,omitempty"`
}

// Response is parsed from the Swift test helper's stdout.
type Response struct {
	Events          []SessionEvent `json:"events"`
	Count           int            `json:"count"`
	UnconsumedCount int            `json:"unconsumed_count"`
	HTTPStatus      int            `json:"http_status"`
	HTTPBody        string         `json:"http_body"`
	RelativeTime    string         `json:"relative_time"`
	Error           string         `json:"error"`
	LogEntryJSON    string         `json:"log_entry_json"`
	// --- macos-notification response fields ---
	NotifyDirs  []string `json:"notify_dirs,omitempty"`
	Title       string   `json:"title,omitempty"`
	Body        string   `json:"body,omitempty"`
	Subtitle    string   `json:"subtitle,omitempty"`
	UserInfoDir string   `json:"user_info_dir,omitempty"`
	OpenedDir        string `json:"opened_dir,omitempty"`
	ConsumedDir      string `json:"consumed_dir,omitempty"`
	ExecutedCommand  string `json:"executed_command,omitempty"`
	AppActivated     bool   `json:"app_activated,omitempty"`
	WindowOpened     bool   `json:"window_opened,omitempty"`
	FocusedVSCodeDir     string `json:"focused_vscode_dir,omitempty"`
	MenuFocusedVSCodeDir string `json:"menu_focused_vscode_dir,omitempty"`
	OpenMethod           string `json:"open_method,omitempty"`
	KoolAttempted        bool   `json:"kool_attempted,omitempty"`
	KoolIpcHandled       bool   `json:"kool_ipc_handled,omitempty"`
	FallbackReason       string `json:"fallback_reason,omitempty"`
	CodeExecuted         bool   `json:"code_executed,omitempty"`
	ResolvedKoolBin      string `json:"resolved_kool_bin,omitempty"`
}

func Run(t *testing.T, req *Request) (*Response, error) {
	projectRoot := filepath.Join(DOCTEST_ROOT, "..", "..")
	helperPath := filepath.Join(projectRoot, ".build", "test-helper")

	helperSrc := filepath.Join(projectRoot, "os-bar-agent-sessionsTests", "TestHelper.swift")
	buildCmd := exec.Command("swiftc", "-o", helperPath, helperSrc)
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("failed to build test helper: %w\n%s", err, out)
	}

	reqJSON, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	cmd := exec.Command(helperPath)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, fmt.Errorf("failed to get stdin pipe: %w", err)
	}
	go func() {
		defer stdin.Close()
		stdin.Write(reqJSON)
		stdin.Write([]byte("\n"))
	}()

	out, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("test helper failed (exit code %v): %w\n%s",
			cmd.ProcessState.ExitCode(), err, out)
	}

	var resp Response
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("failed to parse test helper output: %w\noutput: %s", err, out)
	}

	return &resp, nil
}
```
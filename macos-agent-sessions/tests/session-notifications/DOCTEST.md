# Agent Session Notifications — Doc-Style Test Tree

Test suite for the `SessionStore` and `SessionServer` components of the
`macos-agent-sessions` menu bar app. Validates event storage rules
(add, dedup, prune, cap, sort, relative-time formatting) and HTTP server
behavior (POST /api/notify, error responses).

## Decision Tree

```
session-notifications/                   ROOT: Request{Action, Dir, ...}, Response{Events, Count, ...}
│                                                 Run() wraps Swift test helper via stdin/stdout
│
├── store/                               DECISION: component = store
│   └── [SETUP] req.Action ∈ store actions
│   │
│   ├── add-event/                       LEAF: add one event
│   │   ├── SETUP → req.Action = "add_event", req.Dir = "/a"
│   │   ├── ASSERT → count=1, events[0].dir="/a"
│   │
│   ├── dedup-dir/                       LEAF: same dir twice
│   │   ├── SETUP → add "/a" twice
│   │   ├── ASSERT → count=1, timestamp bumped
│   │
│   ├── prune-old/                       LEAF: 8-day-old event pruned
│   │   ├── SETUP → preload event 8 days ago, action="prune"
│   │   ├── ASSERT → count=0
│   │
│   ├── cap-20/                          LEAF: cap at 20
│   │   ├── SETUP → add 21 distinct dirs
│   │   ├── ASSERT → count=20, oldest evicted
│   │
│   ├── sort-order/                      LEAF: newest-first order
│   │   ├── SETUP → add 3 events with known timestamps
│   │   ├── ASSERT → events[0] is newest
│   │
│   ├── consumed-default/                 LEAF: new event → consumed=false
│   │   ├── SETUP → add_event, dir="/a"
│   │   ├── ASSERT → events[0].consumed==false, unconsumed_count==1
│   │
│   ├── consumed-dedup/                   LEAF: dedup → consumed=false again
│   │   ├── SETUP → preload consumed=true, add same dir
│   │   ├── ASSERT → count==1, events[0].consumed==false
│   │
│   ├── consumed-mark/                    LEAF: markConsumed flips to true
│   │   ├── SETUP → preload consumed=false, mark_consumed same dir
│   │   ├── ASSERT → events[0].consumed==true, unconsumed_count==0
│   │
│   ├── unconsumed-count/                 LEAF: mixed counts correctly
│   │   ├── SETUP → preload 3 events (2 unconsumed, 1 consumed)
│   │   ├── ASSERT → unconsumed_count==2
│   │
│   └── relative-time/                   DECISION: format verification
│       └── [SETUP] req.Action = "relative_time"
│       │
│       ├── sub-1m/                      LEAF: "<1m ago"
│       │   ├── SETUP → timestamp 30s ago
│       │   ├── ASSERT → relative_time = "<1m ago"
│       │
│       ├── exact-minutes/               LEAF: "Xm ago"
│       │   ├── SETUP → timestamp 5m ago
│       │   ├── ASSERT → relative_time = "5m ago"
│       │
│       └── exact-hours/                 LEAF: "Xh ago"
│           ├── SETUP → timestamp 2h ago
│           ├── ASSERT → relative_time = "2h ago"
│
├── command-log-serialize/           LEAF: encode→decode round-trip
│   ├── SETUP → log_command_test with all fields set
│   ├── ASSERT → decoded values match originals, JSON has "command" key
│
├── command-log-null-omission/       LEAF: nil command omits JSON key
│   ├── SETUP → log_command_test without command fields
│   ├── ASSERT → JSON does NOT contain "command" key
│
└── server/                              DECISION: component = server
    └── [SETUP] req.Action ∈ server actions
    │
    ├── post-notify/                     LEAF: valid POST /api/notify
    │   ├── SETUP → POST {"type":"X","dir":"/p"}, Content-Type: application/json
    │   ├── ASSERT → http_status=200, body={"ok":true}, event in store
    │
    ├── type-ignored/                    LEAF: type field accepted and ignored
    │   ├── SETUP → POST with type="cursor", dir="/p2"
    │   ├── ASSERT → http_status=200, dir stored, type not in events
    │
    ├── bad-json/                        LEAF: invalid JSON → 400
    │   ├── SETUP → POST with unparseable body
    │   ├── ASSERT → http_status=400
    │
    ├── missing-dir/                     LEAF: missing or empty dir → 400
    │   ├── SETUP → POST {"type":"X"} (no dir), then POST {"type":"X","dir":""}
    │   ├── ASSERT → both return http_status=400
    │
    ├── wrong-method/                    LEAF: GET /api/notify → 405
    │   ├── SETUP → GET /api/notify
    │   ├── ASSERT → http_status=405
    │
    └── wrong-path/                      LEAF: POST /api/wrong → 404
        ├── SETUP → POST /api/wrong
        ├── ASSERT → http_status=404
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `store/add-event/` | Add one event, verify count=1 and dir matches |
| 2 | `store/dedup-dir/` | Add same dir twice, count stays 1, timestamp updated |
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

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Add single event | `add-event` | ✓ |
| Dedup by dir (bump timestamp) | `dedup-dir` | ✓ |
| Prune events older than 7 days | `prune-old` | ✓ |
| Cap at 20, evict oldest | `cap-20` | ✓ |
| Sort newest-first | `sort-order` | ✓ |
| Relative time: `<1m ago` | `sub-1m` | ✓ |
| Relative time: `Xm ago` | `exact-minutes` | ✓ |
| Relative time: `Xh ago` | `exact-hours` | ✓ |
| Valid POST /api/notify | `post-notify` | ✓ |
| Type field accepted + ignored | `type-ignored` | ✓ |
| Invalid JSON body | `bad-json` | ✓ |
| Missing/empty dir | `missing-dir` | ✓ |
| Wrong HTTP method | `wrong-method` | ✓ |
| Wrong URL path | `wrong-path` | ✓ |
| New event unconsumed by default | `consumed-default` | ✓ |
| Dedup resets consumed | `consumed-dedup` | ✓ |
| Mark consumed flips flag | `consumed-mark` | ✓ |
| Unconsumed count with mixed events | `unconsumed-count` | ✓ |
| Command log encode→decode round-trip | `command-log-serialize` | ✓ |
| Command log nil omission from JSON | `command-log-null-omission` | ✓ |

## How to Run

```sh
# Automated tests (Go doctest framework)
cd macos-agent-sessions && doctest test ./tests/session-notifications

# Vet the test tree structure
cd macos-agent-sessions && doctest vet ./tests/session-notifications

# Run with verbose output
cd macos-agent-sessions && doctest test -v ./tests/session-notifications/...
```

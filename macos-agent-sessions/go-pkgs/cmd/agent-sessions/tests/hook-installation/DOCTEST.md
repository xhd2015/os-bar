# Agent-Sessions Install — Doc-Style Test Tree

Test suite for the `agent-sessions install` subcommand. Validates hook/script
installation for grok, codex, opencode, pi, and claude; codex/claude merge
semantics; dry-run behavior; idempotency; CLI validation; and hook-script
fallback chain content.

All tests run in isolated temporary `HOME` and workspace directories — never
the real user home.


## Version

0.0.2

# DSN (Domain Specific Notion)

The **CLI binary** runs `agent-sessions install` with agent flags (`--grok`, `--codex`,
`--pi`, `--opencode`, `--claude`). The **install logic** writes hook/config files under isolated
`fakeHome` (global) or `workDir` (local). Tests snapshot filesystem state and validate
stdout, exit codes, merge semantics, and idempotency — never the real user home.

Claude differs from codex in two ways: (1) its config is a full `settings.json` that
holds many top-level keys (`permissions`, `env`, `model`, …), so the merge must
preserve every top-level key and only upsert the `Stop` handler; (2) Claude has no
per-hook `env` field, so `AGENT_SESSIONS_AGENT=claude` is conveyed via the command
string (`AGENT_SESSIONS_AGENT=claude '<script>'`). The shared `agent-sessions-stop.sh`
script is unchanged.

## Decision Tree

```
hook-installation/                         ROOT: Request{Action, Target, Global, ...}
│                                                   Response{ExitCode, Files, FakeHome, WorkDir, ...}
│                                                   Run() builds CLI, sets fake HOME, snapshots files
│
├── validation/                            DECISION: CLI flag validation
│   └── [SETUP] req.Action = "install", no Target flag
│   │
│   └── no-target-flag/                    LEAF: install without --pi/--grok/--codex/--opencode
│       ├── SETUP → Target="", no flags
│       ├── ASSERT → exit 1, stderr requires flag, no files under fakeHome/workDir
│
├── grok/                                  DECISION: Target = "grok"
│   └── [SETUP] req.Target = "grok"
│   │
│   ├── local-install/                     LEAF: --grok local
│   │   ├── SETUP → Global=false
│   │   ├── ASSERT → 2 files under workDir, JSON has Stop hook, script 0755
│   │
│   ├── global-install/                    LEAF: --grok --global
│   │   ├── SETUP → Global=true
│   │   ├── ASSERT → files under fakeHome only, not workDir
│   │
│   ├── idempotent/                        LEAF: --grok twice
│   │   ├── SETUP → RunTwice=true
│   │   ├── ASSERT → StdoutSecond has "up to date", file count unchanged
│   │
│   └── dry-run/                           LEAF: --grok --dry-run
│       ├── SETUP → DryRun=true
│       ├── ASSERT → stdout reports install, no files created
│   │
│   └── coexistence/                       DECISION: foreign hook files in .grok/hooks/
│       └── [SETUP] pre-seed separate .json file before install
│       │
│       └── preserves-foreign-file/          LEAF: other-hooks.json unchanged
│           ├── SETUP → testdata/grok-foreign-hooks.json as other-hooks.json
│           ├── ASSERT → foreign file intact + our agent-sessions.json + script
│
├── codex/                                 DECISION: Target = "codex"
│   └── [SETUP] req.Target = "codex"
│   │
│   ├── empty-hooks/                       DECISION: fresh install (no pre-existing hooks.json)
│   │   └── [SETUP] PreExistingHooksJSON = ""
│   │   │
│   │   ├── local/                         LEAF: --codex local, empty hooks
│   │   │   ├── SETUP → Global=false
│   │   │   ├── ASSERT → hooks.json + script under workDir, our Stop entry only
│   │   │
│   │   ├── global/                        LEAF: --codex --global, empty hooks
│   │   │   ├── SETUP → Global=true
│   │   │   ├── ASSERT → files under fakeHome/.codex/
│   │   │
│   │   └── dry-run/                       LEAF: --codex --dry-run, empty hooks
│   │       ├── SETUP → DryRun=true
│   │       ├── ASSERT → stdout reports install, hooks.json MISSING
│   │
│   └── merge/                             DECISION: pre-seeded hooks.json
│       └── [SETUP] loads testdata fixtures into PreExistingHooksJSON
│       │
│       ├── preserves-foreign/             LEAF: foreign UserPromptSubmit + Stop preserved
│       │   ├── SETUP → testdata/codex-foreign-hooks.json
│       │   ├── ASSERT → 2 Stop groups, foreign + ours, UserPromptSubmit intact
│       │
│       ├── upsert-ours/                   LEAF: stale our entry updated, no duplicate
│       │   ├── SETUP → testdata/codex-old-agent-sessions.json
│       │   ├── ASSERT → exactly 1 our Stop, command path updated
│       │
│       ├── empty-hooks-object/            LEAF: {"hooks":{}} → our Stop added
│       │   ├── SETUP → testdata/codex-empty.json
│       │   ├── ASSERT → Stop entry added
│       │
│       └── malformed-preexisting/         LEAF: invalid JSON → error, no corruption
│           ├── SETUP → PreExistingHooksJSON = "{not json"
│           ├── ASSERT → stdout reports merge error, hooks.json unchanged
│
├── claude/                                DECISION: Target = "claude"
│   └── [SETUP] req.Target = "claude"
│   │
│   ├── empty-hooks/                       DECISION: fresh install (no pre-existing settings.json)
│   │   └── [SETUP] PreExistingHooksJSON = ""
│   │   │
│   │   ├── local/                         LEAF: --claude local, empty settings
│   │   │   ├── SETUP → Global=false
│   │   │   ├── ASSERT → settings.json + script under workDir, our Stop only, AGENT_SESSIONS_AGENT=claude, no env
│   │   │
│   │   ├── global/                        LEAF: --claude --global, empty settings
│   │   │   ├── SETUP → Global=true
│   │   │   ├── ASSERT → files under fakeHome/.claude/
│   │   │
│   │   └── dry-run/                       LEAF: --claude --dry-run, empty settings
│   │       ├── SETUP → DryRun=true
│   │       ├── ASSERT → stdout reports install, settings.json MISSING
│   │
│   └── merge/                             DECISION: pre-seeded settings.json
│       └── [SETUP] loads testdata fixtures into PreExistingHooksJSON
│       │
│       ├── preserves-top-level/           LEAF: permissions/env/model + foreign hooks preserved
│       │   ├── SETUP → testdata/claude-foreign-settings.json
│       │   ├── ASSERT → top-level keys intact, foreign hooks intact, our Stop present
│       │
│       ├── upsert-ours/                   LEAF: stale our entry updated, no duplicate
│       │   ├── SETUP → testdata/claude-old-agent-sessions.json
│       │   ├── ASSERT → exactly 1 our Stop, command updated, /old/path.sh gone
│       │
│       └── malformed-preexisting/         LEAF: invalid JSON → merge error, no corruption
│           ├── SETUP → PreExistingHooksJSON = "{not json"
│           ├── ASSERT → stdout reports merge error, settings.json unchanged
│
├── opencode/                              DECISION: Target = "opencode"
│   └── [SETUP] req.Target = "opencode"
│   │
│   ├── local-no-warning/                  LEAF: --opencode local
│   │   ├── SETUP → Global=false
│   │   ├── ASSERT → stdout lacks "/config add plugin"
│   │
│   └── global-install/                    LEAF: --opencode --global
│       ├── SETUP → Global=true
│       ├── ASSERT → plugin at fakeHome/.config/opencode/plugins/
│
├── pi/                                    DECISION: Target = "pi" (smoke)
│   └── [SETUP] req.Target = "pi"
│   │
│   └── local-install/                     LEAF: --pi local
│       ├── SETUP → Global=false
│       ├── ASSERT → workDir/.pi/extensions/agent-sessions-hook.ts exists
│
└── script-content/                        DECISION: hook script content verification
    └── [SETUP] req.Target = "grok" (installs stop script)
    │
    └── hook-script-fallback-chain/         LEAF: script has jq/python3/node/grep chain
        ├── SETUP → grok local install
        ├── ASSERT → script contains fallback markers
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `validation/no-target-flag/` | No target flag → exit 1, stderr error, no files |
| 2 | `grok/local-install/` | `--grok` writes hooks JSON + executable stop script under workDir |
| 3 | `grok/global-install/` | `--grok --global` writes under fakeHome only |
| 4 | `grok/idempotent/` | Second run prints "up to date", files unchanged |
| 5 | `grok/dry-run/` | `--grok --dry-run` reports install, creates no files |
| 6 | `grok/coexistence/preserves-foreign-file/` | Pre-seeded `other-hooks.json` unchanged; our files added |
| 7 | `codex/empty-hooks/local/` | Fresh local codex install creates hooks.json + script |
| 8 | `codex/empty-hooks/global/` | Fresh global codex install under fakeHome |
| 9 | `codex/empty-hooks/dry-run/` | Codex dry-run reports install, hooks.json not created |
| 10 | `codex/merge/preserves-foreign/` | Merge preserves foreign hooks, appends our Stop |
| 11 | `codex/merge/upsert-ours/` | Merge upserts our Stop entry, updates command path |
| 12 | `codex/merge/empty-hooks-object/` | Empty hooks object gets our Stop entry |
| 13 | `codex/merge/malformed-preexisting/` | Malformed pre-existing JSON → error, no write |
| 14 | `claude/empty-hooks/local/` | Fresh local claude install creates settings.json + script |
| 15 | `claude/empty-hooks/global/` | Fresh global claude install under fakeHome |
| 16 | `claude/empty-hooks/dry-run/` | Claude dry-run reports install, settings.json not created |
| 17 | `claude/merge/preserves-top-level/` | Merge preserves top-level keys + foreign hooks, appends our Stop |
| 18 | `claude/merge/upsert-ours/` | Merge upserts our Stop entry, updates command |
| 19 | `claude/merge/malformed-preexisting/` | Malformed pre-existing settings → error, no write |
| 20 | `opencode/local-no-warning/` | Local opencode install has no `/config add plugin` hint |
| 21 | `opencode/global-install/` | Global opencode plugin under fakeHome |
| 22 | `pi/local-install/` | Local pi extension smoke test |
| 23 | `script-content/hook-script-fallback-chain/` | Stop script contains jq/python3/node/grep markers |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Missing required target flag | `no-target-flag` | ✓ |
| Grok local install | `grok/local-install` | ✓ |
| Grok global install (isolated HOME) | `grok/global-install` | ✓ |
| Grok idempotent re-run | `grok/idempotent` | ✓ |
| Grok dry-run | `grok/dry-run` | ✓ |
| Grok preserves foreign hook file | `grok/coexistence/preserves-foreign-file` | ✓ |
| Codex fresh local install | `codex/empty-hooks/local` | ✓ |
| Codex fresh global install | `codex/empty-hooks/global` | ✓ |
| Codex dry-run (no write) | `codex/empty-hooks/dry-run` | ✓ |
| Codex merge preserves foreign hooks | `codex/merge/preserves-foreign` | ✓ |
| Codex merge upserts our entry | `codex/merge/upsert-ours` | ✓ |
| Codex merge into empty hooks object | `codex/merge/empty-hooks-object` | ✓ |
| Codex merge malformed JSON handling | `codex/merge/malformed-preexisting` | ✓ |
| Claude fresh local install | `claude/empty-hooks/local` | ✓ |
| Claude fresh global install (isolated HOME) | `claude/empty-hooks/global` | ✓ |
| Claude dry-run (no write) | `claude/empty-hooks/dry-run` | ✓ |
| Claude merge preserves top-level keys + foreign hooks | `claude/merge/preserves-top-level` | ✓ |
| Claude merge upserts our entry | `claude/merge/upsert-ours` | ✓ |
| Claude merge malformed JSON handling | `claude/merge/malformed-preexisting` | ✓ |
| OpenCode local (no stale warning) | `opencode/local-no-warning` | ✓ |
| OpenCode global install | `opencode/global-install` | ✓ |
| Pi local smoke install | `pi/local-install` | ✓ |
| Hook script fallback chain | `script-content/hook-script-fallback-chain` | ✓ |

## How to Run

```sh
# Automated tests (Go doctest framework)
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/hook-installation

# Vet the test tree structure
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest vet ./tests/hook-installation

# Run with verbose output
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test -v ./tests/hook-installation/...
```

```go
import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

const agentSessionsHookStatus = "os-bar agent-sessions notify"

// Request drives a single install invocation. Defined only at root; descendants must not redefine.
type Request struct {
	Action               string // "install"
	Target               string // "grok" | "codex" | "pi" | "opencode" | "claude" | ""
	Global               bool
	DryRun               bool
	PreExistingHooksJSON     string // write to hooks.json before install (codex merge tests)
	PreExistingGrokHookFile  string // filename under .grok/hooks/ (grok coexistence tests)
	PreExistingGrokHooksJSON string // content for PreExistingGrokHookFile
	RunTwice                 bool   // run install twice (idempotent tests)
}

// Response captures CLI outcome and filesystem snapshots.
type Response struct {
	ExitCode         int
	Stdout           string
	StdoutSecond     string // populated when RunTwice is true
	Stderr           string
	Files            map[string]string // absolute path → content or "MISSING"
	ScriptExecutable map[string]bool   // path → is executable
	FakeHome         string
	WorkDir          string
	Error            string
}

func Run(t *testing.T, req *Request) (*Response, error) {
	fakeHome := filepath.Join(t.TempDir(), "home")
	workDir := filepath.Join(t.TempDir(), "proj")
	if err := os.MkdirAll(fakeHome, 0755); err != nil {
		return nil, fmt.Errorf("mkdir fakeHome: %w", err)
	}
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return nil, fmt.Errorf("mkdir workDir: %w", err)
	}

	pkgDir := filepath.Join(DOCTEST_ROOT, "..", "..")
	binaryPath := filepath.Join(t.TempDir(), "agent-sessions")
	buildCmd := exec.Command("go", "build", "-o", binaryPath, ".")
	buildCmd.Dir = pkgDir
	if out, err := buildCmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("go build failed: %w\n%s", err, out)
	}

	t.Setenv("HOME", fakeHome)

	if req.PreExistingHooksJSON != "" {
		hooksPath := preExistingConfigPath(req.Target, req.Global, fakeHome, workDir)
		if err := os.MkdirAll(filepath.Dir(hooksPath), 0755); err != nil {
			return nil, fmt.Errorf("mkdir preexisting hooks dir: %w", err)
		}
		if err := os.WriteFile(hooksPath, []byte(req.PreExistingHooksJSON), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting hooks.json: %w", err)
		}
	}

	if req.PreExistingGrokHooksJSON != "" {
		filename := req.PreExistingGrokHookFile
		if filename == "" {
			filename = "other-hooks.json"
		}
		base := workDir
		if req.Global {
			base = fakeHome
		}
		hooksPath := filepath.Join(base, ".grok", "hooks", filename)
		if err := os.MkdirAll(filepath.Dir(hooksPath), 0755); err != nil {
			return nil, fmt.Errorf("mkdir preexisting grok hooks dir: %w", err)
		}
		if err := os.WriteFile(hooksPath, []byte(req.PreExistingGrokHooksJSON), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting grok hook file: %w", err)
		}
	}

	args := buildInstallArgs(req)
	run := func() (stdout, stderr string, exitCode int) {
		cmd := exec.Command(binaryPath, args...)
		cmd.Dir = workDir
		cmd.Env = os.Environ()
		var stdoutBuf, stderrBuf strings.Builder
		cmd.Stdout = &stdoutBuf
		cmd.Stderr = &stderrBuf
		err := cmd.Run()
		code := 0
		if err != nil {
			if exitErr, ok := err.(*exec.ExitError); ok {
				code = exitErr.ExitCode()
			} else {
				return "", "", -1
			}
		}
		return stdoutBuf.String(), stderrBuf.String(), code
	}

	stdout, stderr, exitCode := run()
	stdoutSecond := ""
	if req.RunTwice {
		stdoutSecond, _, _ = run()
	}

	paths := expectedPaths(req, fakeHome, workDir)
	files, execMap := snapshotFiles(paths)

	return &Response{
		ExitCode:         exitCode,
		Stdout:           stdout,
		StdoutSecond:     stdoutSecond,
		Stderr:           stderr,
		Files:            files,
		ScriptExecutable: execMap,
		FakeHome:         fakeHome,
		WorkDir:          workDir,
	}, nil
}

func buildInstallArgs(req *Request) []string {
	args := []string{"install"}
	if req.Target != "" {
		args = append(args, "--"+req.Target)
	}
	if req.Global {
		args = append(args, "--global")
	}
	if req.DryRun {
		args = append(args, "--dry-run")
	}
	return args
}

// preExistingConfigPath returns the config file path a merge test pre-seeds
// before running install. Codex pre-seeds <base>/.codex/hooks.json; claude
// pre-seeds <base>/.claude/settings.json. Other targets return "" (no
// pre-seed). Codex behavior is byte-identical to the former codexHooksJSONPath.
func preExistingConfigPath(target string, global bool, fakeHome, workDir string) string {
	base := workDir
	if global {
		base = fakeHome
	}
	switch target {
	case "codex":
		return filepath.Join(base, ".codex", "hooks.json")
	case "claude":
		return filepath.Join(base, ".claude", "settings.json")
	default:
		return ""
	}
}

func expectedPaths(req *Request, fakeHome, workDir string) []string {
	if req.Target == "" {
		return nil
	}
	base := workDir
	if req.Global {
		base = fakeHome
	}
	switch req.Target {
	case "grok":
		return []string{
			filepath.Join(base, ".grok", "hooks", "agent-sessions.json"),
			filepath.Join(base, ".grok", "hooks", "bin", "agent-sessions-stop.sh"),
		}
	case "codex":
		return []string{
			filepath.Join(base, ".codex", "hooks.json"),
			filepath.Join(base, ".codex", "hooks", "agent-sessions-stop.sh"),
		}
	case "claude":
		return []string{
			filepath.Join(base, ".claude", "settings.json"),
			filepath.Join(base, ".claude", "hooks", "agent-sessions-stop.sh"),
		}
	case "opencode":
		if req.Global {
			return []string{filepath.Join(fakeHome, ".config", "opencode", "plugins", "agent-sessions.ts")}
		}
		return []string{filepath.Join(workDir, ".opencode", "plugins", "agent-sessions.ts")}
	case "pi":
		if req.Global {
			return []string{filepath.Join(fakeHome, ".pi", "agent", "extensions", "agent-sessions-hook.ts")}
		}
		return []string{filepath.Join(workDir, ".pi", "extensions", "agent-sessions-hook.ts")}
	default:
		return nil
	}
}

// fileContent returns snapshot content or "MISSING" when the path was not written.
func fileContent(resp *Response, path string) string {
	if content, ok := resp.Files[path]; ok {
		return content
	}
	return "MISSING"
}

// samePath compares paths after Abs+EvalSymlinks (handles /var vs /private/var on macOS).
func samePath(t *testing.T, a, b string) bool {
	t.Helper()
	norm := func(p string) string {
		abs, err := filepath.Abs(p)
		if err != nil {
			t.Fatalf("abs %q: %v", p, err)
		}
		resolved, err := filepath.EvalSymlinks(abs)
		if err != nil {
			return abs
		}
		return resolved
	}
	return norm(a) == norm(b)
}

func snapshotFiles(paths []string) (map[string]string, map[string]bool) {
	files := make(map[string]string)
	execMap := make(map[string]bool)
	for _, p := range paths {
		data, err := os.ReadFile(p)
		if err != nil {
			files[p] = "MISSING"
			continue
		}
		files[p] = string(data)
		if strings.HasSuffix(p, ".sh") {
			if info, err := os.Stat(p); err == nil {
				execMap[p] = info.Mode().Perm()&0111 != 0
			}
		}
	}
	return files, execMap
}

// assertPathIsolated fails if path is not under fakeHome or workDir.
func assertPathIsolated(t *testing.T, path, fakeHome, workDir string) {
	t.Helper()
	absPath, err := filepath.Abs(path)
	if err != nil {
		t.Fatalf("abs path %q: %v", path, err)
	}
	homeAbs, _ := filepath.Abs(fakeHome)
	workAbs, _ := filepath.Abs(workDir)
	if !strings.HasPrefix(absPath, homeAbs+string(filepath.Separator)) &&
		!strings.HasPrefix(absPath, workAbs+string(filepath.Separator)) &&
		absPath != homeAbs && absPath != workAbs {
		t.Fatalf("path %q is outside isolated dirs (fakeHome=%q, workDir=%q)", absPath, fakeHome, workDir)
	}
}

func assertNoFilesUnderDir(t *testing.T, root string) {
	t.Helper()
	_ = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if path == root {
			return nil
		}
		if !info.IsDir() {
			t.Fatalf("unexpected file under isolated dir %q: %s", root, path)
		}
		return nil
	})
}

func assertNoFilesCreated(t *testing.T, resp *Response) {
	t.Helper()
	for path, content := range resp.Files {
		if content != "MISSING" {
			t.Fatalf("expected no files, but %q exists", path)
		}
	}
	assertNoFilesUnderDir(t, resp.FakeHome)
	assertNoFilesUnderDir(t, resp.WorkDir)
}

func parseCodexHooks(t *testing.T, jsonText string) map[string][]json.RawMessage {
	t.Helper()
	var file struct {
		Hooks map[string][]json.RawMessage `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(jsonText), &file); err != nil {
		t.Fatalf("parse hooks.json: %v", err)
	}
	if file.Hooks == nil {
		file.Hooks = make(map[string][]json.RawMessage)
	}
	return file.Hooks
}

func countCodexStopGroups(t *testing.T, jsonText string) int {
	t.Helper()
	hooks := parseCodexHooks(t, jsonText)
	return len(hooks["Stop"])
}

func countOurStopHandlers(t *testing.T, jsonText string) int {
	t.Helper()
	hooks := parseCodexHooks(t, jsonText)
	count := 0
	for _, groupRaw := range hooks["Stop"] {
		var group struct {
			Hooks []struct {
				StatusMessage string `json:"statusMessage"`
			} `json:"hooks"`
		}
		if err := json.Unmarshal(groupRaw, &group); err != nil {
			t.Fatalf("parse Stop group: %v", err)
		}
		for _, h := range group.Hooks {
			if h.StatusMessage == agentSessionsHookStatus {
				count++
			}
		}
	}
	return count
}

func grokHooksHasStop(t *testing.T, jsonText string) bool {
	t.Helper()
	var file struct {
		Hooks map[string]json.RawMessage `json:"hooks"`
	}
	if err := json.Unmarshal([]byte(jsonText), &file); err != nil {
		t.Fatalf("parse grok hooks: %v", err)
	}
	_, ok := file.Hooks["Stop"]
	return ok
}
```

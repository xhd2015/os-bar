# Integrations Agent Install — Doc-Style Test Tree

Test suite for nested `integrations` subcommands (`codex`, `grok`, `pi`,
`opencode`, `claude`) with `--install`, `--dry-run`, and `--global` flags.
Validates CLI routing to existing install logic, help text, regression of
`integrations --json` and `bash-completions`, and per-agent install/dry-run
smoke tests.

All tests run in isolated temporary `HOME` and workspace directories — never
the real user home.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **CLI binary** is the entry point. It parses `integrations` and dispatches
to nested subcommand handlers when a positional argument is present.

The **integrations handler** serves three modes: human-readable status table
(default), JSON listing when `--json` is passed, or nested subcommand dispatch
(`bash-completions`, `codex`, `grok`, `pi`, `opencode`, `claude`).

Each **agent subcommand handler** prints subcommand-specific help when invoked
without `--install`, or delegates to existing install logic when `--install` is
given. With `--dry-run`, install reports planned actions without writing files.
With `--global`, install targets the same global paths as `agent-sessions install
--<agent> --global`.

The **install logic** (`InstallCodex`, `InstallClaude`, `InstallGrok`,
`CheckAndWrite`) writes agent-specific hook/config files and scripts under
project-local (`workDir`) or global (`fakeHome`) locations. Codex/claude merge
semantics are unchanged and tested elsewhere.

The **path shortener** (`pathfmt.Short`) applies only to install CLI stdout
paths (`install →`, `update →`, `up to date →`, and error lines). Local install
messages show cwd-relative paths (`.codex/...`); global install messages show
`~/.codex/...`. File I/O and hooks.json `command` field values remain absolute.

The **global install hint** prints after a successful local codex install,
suggesting `agent-sessions integrations codex --install --global`. It is
suppressed for `--global` install, `--dry-run`, and help-only invocations.

The **fake HOME** is an isolated temp directory. `HOME` is overridden so global
install paths resolve under test control, never touching the real user profile.

The **workDir** is a separate isolated project directory used as `cmd.Dir` for
local installs.

## Decision Tree

```
integrations-agent-install/                 ROOT: Request{Action, Agent, Install, Global, ...}
│                                                    Response{ExitCode, Stdout, Files, FakeHome, WorkDir, ...}
│                                                    Run() builds CLI, sets fake HOME, exec binary
│
├── help/                                   DECISION: help-only invocations
│   └── [SETUP] grouping for integrations and agent subcommand help
│   │
│   ├── integrations-help-has-agent-example/ LEAF: integrations --help
│   │   ├── SETUP → Action=integrations, Args=["--help"]
│   │   ├── ASSERT → exit 0, Examples includes generic agent install line
│   │
│   ├── codex-help-default/                 LEAF: integrations codex (bare)
│   │   ├── SETUP → Action=integrations_agent, Agent=codex, CaptureHelpReference
│   │   ├── ASSERT → exit 0, help describes --install/--dry-run/--global
│   │
│   └── codex-help-flag/                    LEAF: integrations codex --help
│       ├── SETUP → Action=integrations_agent, Agent=codex, Args=["--help"]
│       ├── ASSERT → exit 0, same help via flag
│
├── routing/                                DECISION: regression guards
│   └── [SETUP] req.Action = integrations or bash-completions routing
│   │
│   ├── integrations-json-unchanged/        LEAF: integrations --json --global
│   │   ├── SETUP → Action=integrations, JsonOut=true, Global=true
│   │   ├── ASSERT → exit 0, valid JSON with 4 integrations
│   │
│   └── bash-completions-still-works/       LEAF: integrations bash-completions --install --dry-run
│       ├── SETUP → Action=integrations_bash_completions, Install=true, DryRun=true
│       ├── ASSERT → exit 0, would-install message, no writes
│
├── codex/                                  DECISION: Agent = codex
│   └── [SETUP] req.Agent = "codex"
│   │
│   └── install/                            DECISION: --install flag scenarios
│       └── [SETUP] grouping for codex install/dry-run/global/error paths
│       │
│       ├── dry-run-missing/                LEAF: codex --install --dry-run
│       │   ├── SETUP → Install=true, DryRun=true
│       │   ├── ASSERT → exit 0, shortened .codex paths in report, no hint, no writes
│       │
│       ├── fresh-install-local/            LEAF: codex --install (local)
│       │   ├── SETUP → Install=true, Global=false
│       │   ├── ASSERT → shortened .codex stdout paths, global hint, hooks.json command absolute
│       │
│       ├── fresh-install-global/           LEAF: codex --install --global
│       │   ├── SETUP → Install=true, Global=true
│       │   ├── ASSERT → ~/.codex stdout paths, no hint, files under fakeHome only
│       │
│       └── unknown-flag-rejected/          LEAF: codex --bogus
│           ├── SETUP → Args=["--bogus"]
│           ├── ASSERT → exit 1, stderr unrecognized flag
│
├── claude/                                 DECISION: Agent = claude
│   └── [SETUP] req.Agent = "claude"
│   │
│   └── install/                            DECISION: --install flag scenarios
│       └── [SETUP] grouping for claude install/dry-run/global/error paths
│       │
│       ├── dry-run-missing/                LEAF: claude --install --dry-run
│       │   ├── SETUP → Install=true, DryRun=true
│       │   ├── ASSERT → exit 0, shortened .claude paths in report, no hint, no writes
│       │
│       ├── fresh-install-local/            LEAF: claude --install (local)
│       │   ├── SETUP → Install=true, Global=false
│       │   ├── ASSERT → shortened .claude stdout paths, global hint, settings.json command has AGENT_SESSIONS_AGENT=claude
│       │
│       ├── fresh-install-global/           LEAF: claude --install --global
│       │   ├── SETUP → Install=true, Global=true
│       │   ├── ASSERT → ~/.claude stdout paths, no hint, files under fakeHome only
│       │
│       └── unknown-flag-rejected/          LEAF: claude --bogus
│           ├── SETUP → Args=["--bogus"]
│           ├── ASSERT → exit 1, stderr unrecognized flag
│
├── grok/                                   DECISION: Agent = grok
│   └── [SETUP] req.Agent = "grok"
│   │
│   └── install/
│       └── dry-run-missing/                LEAF: grok --install --dry-run
│           ├── SETUP → Install=true, DryRun=true
│           ├── ASSERT → exit 0, install report, no files created
│
├── pi/                                     DECISION: Agent = pi
│   └── [SETUP] req.Agent = "pi"
│   │
│   └── install/
│       └── dry-run-missing/                LEAF: pi --install --dry-run
│           ├── SETUP → Install=true, DryRun=true
│           ├── ASSERT → exit 0, pi extension install report, no files
│
└── opencode/                               DECISION: Agent = opencode
    └── [SETUP] req.Agent = "opencode"
    │
    └── install/
        └── dry-run-missing/                LEAF: opencode --install --dry-run
            ├── SETUP → Install=true, DryRun=true
            ├── ASSERT → exit 0, opencode plugin install report, no files
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `help/integrations-help-has-agent-example/` | `integrations --help` includes generic agent install example |
| 2 | `help/codex-help-default/` | Bare `integrations codex` prints subcommand help |
| 3 | `help/codex-help-flag/` | `integrations codex --help` matches bare help |
| 4 | `routing/integrations-json-unchanged/` | `integrations --json --global` unchanged |
| 5 | `routing/bash-completions-still-works/` | `bash-completions --install --dry-run` still works |
| 6 | `codex/install/dry-run-missing/` | Codex dry-run shortened paths, no global hint, no writes |
| 7 | `codex/install/fresh-install-local/` | Codex local install shortened paths + global hint |
| 8 | `codex/install/fresh-install-global/` | Codex global install `~/.codex/...` paths, no hint |
| 9 | `codex/install/unknown-flag-rejected/` | Unknown flag on codex subcommand exits 1 |
| 10 | `claude/install/dry-run-missing/` | Claude dry-run shortened paths, no global hint, no writes |
| 11 | `claude/install/fresh-install-local/` | Claude local install shortened paths + global hint |
| 12 | `claude/install/fresh-install-global/` | Claude global install `~/.claude/...` paths, no hint |
| 13 | `claude/install/unknown-flag-rejected/` | Unknown flag on claude subcommand exits 1 |
| 14 | `grok/install/dry-run-missing/` | Grok dry-run smoke test |
| 15 | `pi/install/dry-run-missing/` | Pi dry-run smoke test |
| 16 | `opencode/install/dry-run-missing/` | OpenCode dry-run smoke test |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Integrations help agent example | `integrations-help-has-agent-example` | ✓ |
| Codex default help | `codex-help-default` | ✓ |
| Codex --help flag | `codex-help-flag` | ✓ |
| Integrations JSON routing regression | `integrations-json-unchanged` | ✓ |
| Bash-completions routing regression | `bash-completions-still-works` | ✓ |
| Codex dry-run shortened paths, no hint | `codex/install/dry-run-missing` | ✓ |
| Codex local install shortened paths + hint | `codex/install/fresh-install-local` | ✓ |
| Codex global install ~/.codex paths, no hint | `codex/install/fresh-install-global` | ✓ |
| Codex help has no global hint | `help/codex-help-default`, `help/codex-help-flag` | ✓ |
| Codex unknown flag rejection | `codex/install/unknown-flag-rejected` | ✓ |
| Claude dry-run shortened paths, no hint | `claude/install/dry-run-missing` | ✓ |
| Claude local install shortened paths + hint | `claude/install/fresh-install-local` | ✓ |
| Claude global install ~/.claude paths, no hint | `claude/install/fresh-install-global` | ✓ |
| Claude unknown flag rejection | `claude/install/unknown-flag-rejected` | ✓ |
| Grok routing + dry-run smoke | `grok/install/dry-run-missing` | ✓ |
| Pi routing + dry-run smoke | `pi/install/dry-run-missing` | ✓ |
| OpenCode routing + dry-run smoke | `opencode/install/dry-run-missing` | ✓ |

## How to Run

```sh
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest vet ./tests/integrations-agent-install
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/integrations-agent-install
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test -v ./tests/integrations-agent-install/...
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/integrations-agent-install/codex/...
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

type Request struct {
	Action               string   // "integrations" | "integrations_agent" | "integrations_bash_completions"
	Agent                string   // "codex" | "grok" | "pi" | "opencode" | "claude"
	Args                 []string // extra CLI args after flags
	JsonOut              bool     // integrations --json
	Global               bool     // --global
	Install              bool     // agent/bash-completions --install
	DryRun               bool     // agent/bash-completions --dry-run
	CaptureHelpReference bool     // capture agent --help stdout for comparison
}

type Response struct {
	ExitCode            int
	Stdout              string
	Stderr              string
	Files               map[string]string // absolute path → content or "MISSING"
	ScriptExecutable    map[string]bool   // path → is executable (.sh scripts)
	FakeHome            string
	WorkDir             string
	CompletionPath      string
	HelpReferenceStdout string
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
	completionPath := completionPath(fakeHome)

	execCLI := func(args []string) (stdout, stderr string, exitCode int) {
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

	args := buildIntegrationsArgs(req)
	stdout, stderr, exitCode := execCLI(args)

	helpRef := ""
	if req.CaptureHelpReference && req.Agent != "" {
		helpArgs := []string{"integrations", req.Agent, "--help"}
		helpRef, _, _ = execCLI(helpArgs)
	}

	paths := expectedAgentPaths(req, fakeHome, workDir)
	if req.Action == "integrations_bash_completions" {
		paths = append(paths, completionPath)
	}
	files, execMap := snapshotFiles(paths)

	return &Response{
		ExitCode:            exitCode,
		Stdout:              stdout,
		Stderr:              stderr,
		Files:               files,
		ScriptExecutable:    execMap,
		FakeHome:            fakeHome,
		WorkDir:             workDir,
		CompletionPath:      completionPath,
		HelpReferenceStdout: helpRef,
	}, nil
}
```
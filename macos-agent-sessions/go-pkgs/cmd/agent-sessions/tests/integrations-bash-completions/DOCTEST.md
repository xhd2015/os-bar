# Integrations Bash-Completions — Doc-Style Test Tree

Test suite for `agent-sessions integrations` help examples, dual-scope
human-readable default output, the nested `bash-completions` subcommand, bash
completion install/update/dry-run semantics, bash profile sourcing, and
regression of existing `integrations --json` behavior.

All tests run in isolated temporary `HOME` and workspace directories — never
the real user home.

## Version

0.0.2

# DSN (Domain Specific Notion)

The **CLI binary** is the entry point. It parses top-level subcommands and
delegates to handlers.

The **integrations handler** serves three modes: printing a human-readable
status table by default (`[--global] [--local]`), listing integration install
status as JSON when `--json` is passed (`--json [--global] [--local]`), or
dispatching to nested subcommands when a positional argument is present
(`bash-completions`).

The **scope resolver** determines which install locations to check. With no
scope flags, both global (`~`) and project-local (`cwd`) paths are included.
`--global` alone checks global paths; `--local` alone checks local paths;
`--global --local` is equivalent to the default.

The **human formatter** renders scope-aware headers and rows. Single-scope
mode uses `Integrations (global):` or `Integrations (local):` with one row per
agent and no scope suffixes. Dual-scope mode uses bare `Integrations:` and
omits or merges rows by per-scope existence: when both scopes are missing,
one row with `Missing (Global + Local)` and the global path only; when only
one scope is present, one row with that scope's status and path; when both are
non-missing with the same status, one collapsed row with `(Global + Local)` and
joined paths; only when both scopes are non-missing with different statuses
does the formatter emit two rows with `(Global)` and `(Local)` suffixes.

The **path shortener** (`pathfmt.Short`) applies only to human-readable path
columns. Global install paths under `HOME` display as `~/...`; local paths under
the process cwd display as cwd-relative (e.g. `.grok/...`); joined dual paths
shorten each side independently (`~/... + .grok/...`). JSON output and file I/O
keep absolute paths unchanged.

The **bash-completions handler** prints subcommand help when invoked without
`--install`, or installs/updates an embedded completion script and ensures the
user's bash profile sources it when `--install` is given. With `--dry-run`, it
reports the planned file and profile actions without writing.

The **fake HOME** is an isolated temp directory. `HOME` is overridden so install
paths resolve under test control, never touching the real user profile.

The **completion file** lives at
`$HOME/.config/agent-sessions/bash-completion.bash`. Content is embedded in the
binary via `//go:embed` and must register completion for the full
`agent-sessions` command tree.

The **bash profile** is `$HOME/.bash_profile` on macOS bash. Install appends a
marked source block when the profile does not already contain the completion
path substring. If the substring is already present, the profile is left
unchanged (idempotent).

## Decision Tree

```
integrations-bash-completions/              ROOT: Request{Action, JsonOut, Global, Local, ...}
│                                                    Response{ExitCode, Stdout, Files{...}, ...}
│                                                    Run() builds CLI, sets fake HOME, exec binary
│
├── help/                                   DECISION: Action = help scenarios
│   └── [SETUP] grouping for help-only invocations
│   │
│   ├── integrations-help-has-examples/     LEAF: integrations --help
│   │   ├── SETUP → Action=integrations, Args=["--help"]
│   │   ├── ASSERT → exit 0, Examples with dual-scope + --local docs
│   │
│   ├── bash-completions-help-default/      LEAF: integrations bash-completions (bare)
│   │   ├── SETUP → Action=integrations_bash_completions, CaptureHelpReference
│   │   ├── ASSERT → exit 0, help describes ~/.bash_profile direct sourcing
│   │
│   └── bash-completions-help-flag/         LEAF: integrations bash-completions --help
│       ├── SETUP → Action=integrations_bash_completions, Args=["--help"]
│       ├── ASSERT → exit 0, usage/flags/examples, no framework-dir path
│
├── bash-completions/                       DECISION: Action = integrations_bash_completions
│   └── [SETUP] req.Action = integrations_bash_completions
│   │
│   └── install/                            DECISION: --install flag scenarios
│       └── [SETUP] grouping for install/dry-run/profile/error paths
│       │
│       ├── fresh-install/                  LEAF: --install on empty fakeHome
│       ├── profile-append-on-install/      LEAF: missing profile, --install
│       ├── profile-already-sources/        LEAF: profile pre-seeded with source, --install
│       ├── idempotent-reinstall/           LEAF: --install twice
│       ├── update-existing/                LEAF: stale completion + profile already sources
│       ├── dry-run-missing/                LEAF: --install --dry-run, no files
│       ├── dry-run-existing/               LEAF: matching completion, --install --dry-run
│       ├── dry-run-would-update/           LEAF: stale completion, --install --dry-run
│       └── unknown-flag-rejected/          LEAF: --bogus flag
│
├── human-output/                           DECISION: human-readable (JsonOut=false)
│   └── [SETUP] req.Action = integrations
│   │
│   ├── default-both-scopes/                LEAF: integrations (no flags)
│   │   ├── SETUP → default flags
│   │   ├── ASSERT → Integrations: header, 5 Missing (Global + Local) rows
│   │
│   ├── local-only/                         LEAF: integrations --local
│   │   ├── SETUP → Local=true
│   │   ├── ASSERT → Integrations (local):, 4 rows, no suffixes
│   │
│   ├── global-only/                        LEAF: integrations --global
│   │   ├── SETUP → Global=true
│   │   ├── ASSERT → Integrations (global):, 4 rows, no suffixes
│   │
│   ├── both-flags-same-as-default/         LEAF: integrations --global --local
│   │   ├── SETUP → Global=true, Local=true
│   │   ├── ASSERT → same as default-both-scopes
│   │
│   ├── all-missing-global/                 LEAF: empty fakeHome + --global
│   │   ├── SETUP → Global=true
│   │   ├── ASSERT → all four rows Missing, no suffixes
│   │
│   ├── status-labels-global/               LEAF: grok installed + --global
│   │   ├── SETUP → Global=true, SeedGrokViaInstall=true
│   │   ├── ASSERT → grok Up to date, others Missing
│   │
│   ├── global-plus-local-installed/        LEAF: grok global+local seeded
│   │   ├── SETUP → SeedGrokViaInstall + SeedGrokLocal
│   │   ├── ASSERT → grok collapsed Up to date (Global + Local)
│   │
│   ├── local-only-installed/               LEAF: grok local only seeded
│   │   ├── SETUP → SeedGrokLocal=true
│   │   ├── ASSERT → grok Up to date (Local); others Missing (Global + Local)
│   │
│   ├── different-statuses-both-installed/  LEAF: grok global up_to_date, local outdated
│   │   ├── SETUP → seeds + CorruptGrokLocalHooks
│   │   ├── ASSERT → grok 2 rows (Global)/(Local); others collapsed missing
│   │
│   ├── mixed-scopes/                       LEAF: grok global only seeded
│   │   ├── SETUP → SeedGrokViaInstall=true
│   │   ├── ASSERT → grok Up to date (Global); others Missing (Global + Local)
│   │
│   ├── json-both-scopes/                   LEAF: integrations --json
│   │   ├── SETUP → JsonOut=true
│   │   ├── ASSERT → 8 entries, global+local scopes
│   │
│   ├── json-local-only/                    LEAF: integrations --json --local
│   │   ├── SETUP → JsonOut=true, Local=true
│   │   ├── ASSERT → 5 entries, scope=local
│   │
│   ├── json-still-works/                   LEAF: integrations --json --global
│   │   ├── SETUP → JsonOut=true, Global=true
│   │   ├── ASSERT → valid JSON with 5 integrations
│   │
│   └── path-shortening/                    DECISION: human path display rules
│       └── [SETUP] grouping for pathfmt.Short display assertions
│       │
│       ├── global-tilde-paths/             LEAF: --global, all missing, ~/... paths
│       ├── local-relative-paths/           LEAF: --local, all missing, .foo/... paths
│       ├── dual-joined-shortened/          LEAF: grok both scopes, ~/... + .grok/...
│       └── no-absolute-leak/               LEAF: default dual-scope, no temp prefixes
│
└── routing/                                DECISION: integrations JSON regression
    └── [SETUP] req.Action = integrations, JsonOut=true
    │
    └── integrations-json-unchanged/        LEAF: integrations --json --global
        ├── SETUP → Global=true
        ├── ASSERT → exit 0, valid JSON with 5 integrations
```

## Test Index

| # | Leaf | Description |
|---|------|-------------|
| 1 | `help/integrations-help-has-examples/` | `integrations --help` documents dual-scope default and `--local` |
| 2 | `help/bash-completions-help-default/` | Bare `bash-completions` prints help with direct profile sourcing |
| 3 | `help/bash-completions-help-flag/` | `bash-completions --help` shows usage, flags, examples |
| 4 | `bash-completions/install/fresh-install/` | Fresh `--install` creates completion + appends profile source |
| 5 | `bash-completions/install/profile-append-on-install/` | Missing profile gains source block on install |
| 6 | `bash-completions/install/profile-already-sources/` | Pre-sourced profile left byte-identical on install |
| 7 | `bash-completions/install/idempotent-reinstall/` | Second `--install` reports up to date, profile not duplicated |
| 8 | `bash-completions/install/update-existing/` | Stale completion updated; profile untouched |
| 9 | `bash-completions/install/dry-run-missing/` | Dry-run reports would install; no file writes |
| 10 | `bash-completions/install/dry-run-existing/` | Dry-run on matching file reports up to date |
| 11 | `bash-completions/install/dry-run-would-update/` | Dry-run on stale file reports would update |
| 12 | `bash-completions/install/unknown-flag-rejected/` | Unknown flag exits 1 with error |
| 13 | `human-output/default-both-scopes/` | `integrations` prints 5 collapsed Missing (Global + Local) rows |
| 14 | `human-output/local-only/` | `integrations --local` prints local human table |
| 15 | `human-output/global-only/` | `integrations --global` prints global human table |
| 16 | `human-output/both-flags-same-as-default/` | `--global --local` same as default |
| 17 | `human-output/all-missing-global/` | Empty HOME + `--global` → all `Missing`, no suffixes |
| 18 | `human-output/status-labels-global/` | Seeded grok → `Up to date`, others `Missing` |
| 19 | `human-output/global-plus-local-installed/` | Grok both scopes → collapsed `(Global + Local)` row |
| 20 | `human-output/local-only-installed/` | Grok local only → `Up to date (Local)` under dual-scope default |
| 21 | `human-output/different-statuses-both-installed/` | Grok global up_to_date + local outdated → 2 split rows |
| 22 | `human-output/mixed-scopes/` | Grok global only → `Up to date (Global)`; others collapsed missing |
| 23 | `human-output/json-both-scopes/` | `--json` returns 10 global+local entries |
| 24 | `human-output/json-local-only/` | `--json --local` returns 5 local entries |
| 25 | `human-output/json-still-works/` | `--json --global` JSON regression from human-output branch |
| 26 | `human-output/path-shortening/global-tilde-paths/` | `--global` rows show `~/...` not absolute HOME |
| 27 | `human-output/path-shortening/local-relative-paths/` | `--local` rows show cwd-relative `.foo/...` paths |
| 28 | `human-output/path-shortening/dual-joined-shortened/` | Collapsed row joins `~/... + .grok/...` |
| 29 | `human-output/path-shortening/no-absolute-leak/` | Default dual-scope stdout has no temp-dir prefixes |
| 30 | `routing/integrations-json-unchanged/` | `integrations --json --global` unchanged |

## Coverage Map

| Scenario | Leaf | Coverage |
|----------|------|----------|
| Integrations help dual-scope + --local | `integrations-help-has-examples` | ✓ |
| Bash-completions default help | `bash-completions-help-default` | ✓ |
| Bash-completions --help flag | `bash-completions-help-flag` | ✓ |
| Fresh completion + profile install | `fresh-install` | ✓ |
| Profile append on missing profile | `profile-append-on-install` | ✓ |
| Profile skip when already sources | `profile-already-sources` | ✓ |
| Idempotent reinstall | `idempotent-reinstall` | ✓ |
| Update stale completion | `update-existing` | ✓ |
| Dry-run missing files | `dry-run-missing` | ✓ |
| Dry-run matching file | `dry-run-existing` | ✓ |
| Dry-run would update | `dry-run-would-update` | ✓ |
| Unknown flag rejection | `unknown-flag-rejected` | ✓ |
| Default dual-scope collapsed missing rows | `default-both-scopes` | ✓ |
| Human table local only | `local-only` | ✓ |
| Human table global only | `global-only` | ✓ |
| Both scope flags = default | `both-flags-same-as-default` | ✓ |
| All missing human labels (global) | `all-missing-global` | ✓ |
| Mixed human status labels (global) | `status-labels-global` | ✓ |
| Collapsed dual-scope row (same status) | `global-plus-local-installed` | ✓ |
| Local-only installed dual-scope row | `local-only-installed` | ✓ |
| Split dual-scope rows (different statuses) | `different-statuses-both-installed` | ✓ |
| Global-only installed dual-scope row | `mixed-scopes` | ✓ |
| JSON both scopes (10 entries) | `json-both-scopes` | ✓ |
| JSON local only (5 entries) | `json-local-only` | ✓ |
| JSON path --global regression | `json-still-works` | ✓ |
| Human global paths shortened to ~/ | `global-tilde-paths`, all global-scope human leaves | ✓ |
| Human local paths cwd-relative | `local-relative-paths`, `local-only` | ✓ |
| Human joined dual paths shortened | `dual-joined-shortened`, `global-plus-local-installed` | ✓ |
| No absolute temp prefixes in human stdout | `no-absolute-leak`, all human leaves | ✓ |
| JSON paths remain absolute | `json-both-scopes`, `json-local-only`, `json-still-works` | ✓ |
| Integrations JSON routing regression | `integrations-json-unchanged` | ✓ |

## How to Run

```sh
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest vet ./tests/integrations-bash-completions
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/integrations-bash-completions
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test ./tests/integrations-bash-completions/human-output/...
cd macos-agent-sessions/go-pkgs/cmd/agent-sessions && doctest test -v ./tests/integrations-bash-completions/...
```

```go
import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

type Request struct {
	Action                 string
	Args                   []string
	JsonOut                bool
	Global                 bool
	Local                  bool
	SeedGrokViaInstall     bool
	SeedGrokLocal          bool
	CorruptGrokLocalHooks  bool
	DryRun                 bool
	Install                bool
	PreExistingCompletion  string
	PreExistingProfile     string
	RunTwice               bool
	SeedMatchingCompletion bool
	CaptureHelpReference   bool
}

type Response struct {
	ExitCode            int
	Stdout              string
	StdoutSecond        string
	Stderr              string
	Files               map[string]string
	FakeHome            string
	WorkDir             string
	CompletionPath      string
	ProfilePath         string
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
	profilePath := profilePath(fakeHome)

	if req.PreExistingCompletion != "" {
		if err := os.MkdirAll(filepath.Dir(completionPath), 0755); err != nil {
			return nil, fmt.Errorf("mkdir preexisting completion dir: %w", err)
		}
		if err := os.WriteFile(completionPath, []byte(req.PreExistingCompletion), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting completion: %w", err)
		}
	}

	if req.PreExistingProfile != "" {
		if err := os.WriteFile(profilePath, []byte(req.PreExistingProfile), 0644); err != nil {
			return nil, fmt.Errorf("write preexisting profile: %w", err)
		}
	}

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

	if req.SeedMatchingCompletion {
		seedArgs := []string{"integrations", "bash-completions", "--install"}
		if _, _, code := execCLI(seedArgs); code != 0 {
			return nil, fmt.Errorf("seed install failed with exit code %d", code)
		}
	}

	if req.SeedGrokViaInstall {
		seedArgs := []string{"install", "--grok", "--global"}
		if _, _, code := execCLI(seedArgs); code != 0 {
			return nil, fmt.Errorf("seed grok global install failed with exit code %d", code)
		}
	}

	if req.SeedGrokLocal {
		seedArgs := []string{"install", "--grok"}
		if _, _, code := execCLI(seedArgs); code != 0 {
			return nil, fmt.Errorf("seed grok local install failed with exit code %d", code)
		}
	}

	if req.CorruptGrokLocalHooks {
		localHooks := filepath.Join(workDir, ".grok", "hooks", "agent-sessions.json")
		if err := os.MkdirAll(filepath.Dir(localHooks), 0755); err != nil {
			return nil, fmt.Errorf("mkdir corrupt grok local hooks dir: %w", err)
		}
		if err := os.WriteFile(localHooks, []byte(`{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"stale"}]}]}}`), 0644); err != nil {
			return nil, fmt.Errorf("write corrupt grok local hooks: %w", err)
		}
	}

	args := buildIntegrationsArgs(req)
	stdout, stderr, exitCode := execCLI(args)

	stdoutSecond := ""
	if req.RunTwice {
		stdoutSecond, _, _ = execCLI(args)
	}

	helpRef := ""
	if req.CaptureHelpReference {
		helpRef, _, _ = execCLI([]string{"integrations", "bash-completions", "--help"})
	}

	files := snapshotInstallFiles(completionPath, profilePath)

	return &Response{
		ExitCode:            exitCode,
		Stdout:              stdout,
		StdoutSecond:        stdoutSecond,
		Stderr:              stderr,
		Files:               files,
		FakeHome:            fakeHome,
		WorkDir:             workDir,
		CompletionPath:      completionPath,
		ProfilePath:         profilePath,
		HelpReferenceStdout: helpRef,
	}, nil
}
```
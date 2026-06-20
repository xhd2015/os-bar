package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	lessflags "github.com/xhd2015/less-flags"
	"github.com/xhd2015/os-bar/macos-agent-sessions/go-pkgs/integrations"
)

func cmdIntegrations(args []string) {
	var jsonOut bool
	var global bool

	helpText := `Usage: agent-sessions integrations [flags]

Report install status for grok, opencode, pi, and codex integrations.

Flags:
  --json          output machine-readable JSON
  --global        check global install locations (default: project-local)
  -h, --help      show help
`

	_, err := lessflags.Bool("--json", &jsonOut).
		Bool("--global", &global).
		Help("-h,--help", helpText).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if !jsonOut {
		fmt.Fprintf(os.Stderr, "error: --json is required\n")
		os.Exit(1)
	}

	homeDir, _ := os.UserHomeDir()
	cwd, _ := os.Getwd()

	entries := integrations.List(global, homeDir, cwd)
	out, err := json.Marshal(integrations.IntegrationsResponse{Integrations: entries})
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to marshal JSON: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(out))
}

func cmdInstall(args []string) {
	var showPi bool
	var showOpencode bool
	var showGrok bool
	var showCodex bool
	var dryRun bool
	var global bool

	helpText := `Usage: agent-sessions install [flags]

Install or update integration scripts for pi, opencode, grok, and codex.
Checks whether the bundled script is already installed and compares content.

Flags:
  --pi            install/check pi extension
  --opencode      install/check opencode plugin
  --grok          install/check grok Stop notification hook
  --codex         install/check codex Stop notification hook
  --dry-run       check status only, do not write files
  --global        install to global dir
                  pi: ~/.pi/agent/extensions/
                  opencode: ~/.config/opencode/plugins/
                  grok: ~/.grok/hooks/
                  codex: ~/.codex/
                  default: project-local
  -h, --help      show help
`

	_, err := lessflags.Bool("--pi", &showPi).
		Bool("--opencode", &showOpencode).
		Bool("--grok", &showGrok).
		Bool("--codex", &showCodex).
		Bool("--dry-run", &dryRun).
		Bool("--global", &global).
		Help("-h,--help", helpText).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if !showPi && !showOpencode && !showGrok && !showCodex {
		fmt.Fprintf(os.Stderr, "error: at least one of --pi, --opencode, --grok, or --codex is required\n")
		os.Exit(1)
	}

	homeDir, _ := os.UserHomeDir()
	cwd, _ := os.Getwd()

	if showPi {
		var targetPath string
		if global {
			targetPath = filepath.Join(homeDir, ".pi", "agent", "extensions", "agent-sessions-hook.ts")
		} else {
			targetPath = filepath.Join(cwd, ".pi", "extensions", "agent-sessions-hook.ts")
		}
		integrations.CheckAndWrite("pi extension", targetPath, integrations.PiExtension(), dryRun)
	}

	if showOpencode {
		var targetPath string
		if global {
			targetPath = filepath.Join(homeDir, ".config", "opencode", "plugins", "agent-sessions.ts")
		} else {
			targetPath = filepath.Join(cwd, ".opencode", "plugins", "agent-sessions.ts")
		}
		written := integrations.CheckAndWrite("opencode plugin", targetPath, integrations.OpencodePlugin(), dryRun)
		if written && !dryRun && global {
			fmt.Println()
			fmt.Println("  To enable, run this inside opencode:")
			fmt.Printf("    /config add plugin file://%s\n", targetPath)
		}
	}

	if showGrok {
		integrations.InstallGrok(global, homeDir, cwd, dryRun)
	}

	if showCodex {
		integrations.InstallCodex(global, homeDir, cwd, dryRun)
	}
}
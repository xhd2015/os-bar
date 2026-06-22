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
	var local bool

	helpText := `Usage: agent-sessions integrations [flags] [subcommand]

Report install status for grok, opencode, pi, and codex integrations.
By default both global and project-local scopes are listed.

Flags:
  --json          output machine-readable JSON (default: human-readable table)
  --global        include global install locations only
  --local         include project-local install locations only
  -h, --help      show help

If neither --global nor --local is set, both scopes are listed.
If both --global and --local are set, both scopes are listed.

Examples:
  agent-sessions integrations
  agent-sessions integrations --global
  agent-sessions integrations --local
  agent-sessions integrations --json
  agent-sessions integrations --json --global
  agent-sessions integrations bash-completions --install
  agent-sessions integrations codex --install
`

	remainArgs, err := lessflags.Bool("--json", &jsonOut).
		Bool("--global", &global).
		Bool("--local", &local).
		Help("-h,--help", helpText).
		StopOnFirstArg().
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if len(remainArgs) > 0 {
		switch remainArgs[0] {
		case "bash-completions":
			cmdIntegrationsBashCompletions(remainArgs[1:])
			return
		case "codex", "grok", "pi", "opencode":
			cmdIntegrationsAgent(remainArgs[0], remainArgs[1:])
			return
		default:
			fmt.Fprintf(os.Stderr, "error: unknown subcommand: %s\n", remainArgs[0])
			os.Exit(1)
		}
	}

	homeDir, _ := os.UserHomeDir()
	cwd, _ := os.Getwd()

	includeGlobal, includeLocal := resolveIntegrationScopes(global, local)
	entries := integrations.ListScopes(includeGlobal, includeLocal, homeDir, cwd)
	if !jsonOut {
		printIntegrationsHuman(entries, includeGlobal, includeLocal)
		return
	}

	out, err := json.Marshal(integrations.IntegrationsResponse{Integrations: entries})
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: failed to marshal JSON: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(out))
}

func humanIntegrationStatusLabel(status string) string {
	switch status {
	case "missing":
		return "Missing"
	case "up_to_date":
		return "Up to date"
	case "outdated":
		return "Outdated"
	default:
		return status
	}
}

func resolveIntegrationScopes(global, local bool) (includeGlobal, includeLocal bool) {
	if !global && !local {
		return true, true
	}
	return global, local
}

func printIntegrationsHuman(entries []integrations.IntegrationEntry, includeGlobal, includeLocal bool) {
	if includeGlobal && includeLocal {
		fmt.Println("Integrations:")
		printDualScopeHumanRows(entries)
		return
	}
	if includeGlobal {
		fmt.Println("Integrations (global):")
	} else {
		fmt.Println("Integrations (local):")
	}
	for _, entry := range entries {
		fmt.Printf("  %-10s %-12s %s\n", entry.ID, humanIntegrationStatusLabel(entry.Status), entry.Path)
	}
}

func printDualScopeHumanRows(entries []integrations.IntegrationEntry) {
	for i := 0; i < len(entries); i += 2 {
		if i+1 >= len(entries) {
			printDualScopeHumanRow(entries[i], dualScopeLabel(entries[i].Scope))
			continue
		}
		globalEntry := entries[i]
		localEntry := entries[i+1]
		if globalEntry.Scope != "global" {
			globalEntry, localEntry = localEntry, globalEntry
		}
		if globalEntry.Status == localEntry.Status && globalEntry.Status != "missing" {
			label := humanIntegrationStatusLabel(globalEntry.Status) + " (Global + Local)"
			path := globalEntry.Path + " + " + localEntry.Path
			fmt.Printf("  %-10s %-30s %s\n", globalEntry.ID, label, path)
			continue
		}
		printDualScopeHumanRow(globalEntry, "Global")
		printDualScopeHumanRow(localEntry, "Local")
	}
}

func dualScopeLabel(scope string) string {
	if scope == "global" {
		return "Global"
	}
	return "Local"
}

func printDualScopeHumanRow(entry integrations.IntegrationEntry, scopeLabel string) {
	label := humanIntegrationStatusLabel(entry.Status) + " (" + scopeLabel + ")"
	fmt.Printf("  %-10s %-30s %s\n", entry.ID, label, entry.Path)
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
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	lessflags "github.com/xhd2015/less-flags"
	"github.com/xhd2015/os-bar/macos-agent-sessions/go-pkgs/integrations"
)

func agentHelpText(agent string) string {
	descriptions := map[string]string{
		"codex":    "Install or update codex Stop notification hook.",
		"grok":     "Install or update grok Stop notification hook.",
		"pi":       "Install or update pi extension.",
		"opencode": "Install or update opencode plugin.",
		"claude":   "Install or update claude Stop notification hook.",
	}
	desc := descriptions[agent]
	return fmt.Sprintf(`Usage: agent-sessions integrations %s [flags]

%s

Flags:
  --install       install or update integration files
  --dry-run       report planned action without writing files
  --global        install to global dir (default: project-local)
  -h, --help      show help

Examples:
  agent-sessions integrations %s --install
  agent-sessions integrations %s --install --dry-run
  agent-sessions integrations %s --install --global
`, agent, desc, agent, agent, agent)
}

func printAgentHelp(agent string) {
	txt := strings.TrimPrefix(agentHelpText(agent), "\n")
	fmt.Print(txt)
	if !strings.HasSuffix(txt, "\n") {
		fmt.Println()
	}
}

func installPiIntegration(global bool, homeDir, cwd string, dryRun bool) {
	var targetPath string
	if global {
		targetPath = filepath.Join(homeDir, ".pi", "agent", "extensions", "agent-sessions-hook.ts")
	} else {
		targetPath = filepath.Join(cwd, ".pi", "extensions", "agent-sessions-hook.ts")
	}
	integrations.CheckAndWrite("pi extension", targetPath, integrations.PiExtension(), dryRun)
}

func installOpencodeIntegration(global bool, homeDir, cwd string, dryRun bool) {
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

func cmdIntegrationsAgent(agent string, args []string) {
	var install bool
	var dryRun bool
	var global bool

	_, err := lessflags.Bool("--install", &install).
		Bool("--dry-run", &dryRun).
		Bool("--global", &global).
		HelpFunc("-h,--help", func() { printAgentHelp(agent) }).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if !install {
		printAgentHelp(agent)
		return
	}

	homeDir, _ := os.UserHomeDir()
	cwd, _ := os.Getwd()

	switch agent {
	case "codex":
		integrations.InstallCodex(global, homeDir, cwd, dryRun)
		if !global && !dryRun {
			fmt.Println()
			fmt.Println("  To install globally, run:")
			fmt.Printf("    agent-sessions integrations codex --install --global\n")
		}
	case "claude":
		integrations.InstallClaude(global, homeDir, cwd, dryRun)
		if !global && !dryRun {
			fmt.Println()
			fmt.Println("  To install globally, run:")
			fmt.Printf("    agent-sessions integrations claude --install --global\n")
		}
	case "grok":
		integrations.InstallGrok(global, homeDir, cwd, dryRun)
	case "pi":
		installPiIntegration(global, homeDir, cwd, dryRun)
	case "opencode":
		installOpencodeIntegration(global, homeDir, cwd, dryRun)
	}
}
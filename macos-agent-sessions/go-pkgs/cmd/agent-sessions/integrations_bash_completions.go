package main

import (
	_ "embed"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	lessflags "github.com/xhd2015/less-flags"
)

//go:embed embed/agent-sessions.bash
var bashCompletionScript []byte

const profileSourceSubstring = ".config/agent-sessions/bash-completion.bash"

const profileSourceBlock = `# agent-sessions bash completion
[[ -f "$HOME/.config/agent-sessions/bash-completion.bash" ]] && source "$HOME/.config/agent-sessions/bash-completion.bash"
`

func bashCompletionsHelpText() string {
	return `Usage: agent-sessions integrations bash-completions [flags]

Install or update bash tab completion for agent-sessions.
Writes the completion script to ~/.config/agent-sessions/bash-completion.bash
and sources it from ~/.bash_profile when needed.

Flags:
  --install       install or update completion script and ensure ~/.bash_profile sources it
  --dry-run       report planned action without writing files
  -h, --help      show help

Examples:
  agent-sessions integrations bash-completions --install
  agent-sessions integrations bash-completions --install --dry-run
`
}

func printBashCompletionsHelp() {
	txt := strings.TrimPrefix(bashCompletionsHelpText(), "\n")
	fmt.Print(txt)
	if !strings.HasSuffix(txt, "\n") {
		fmt.Println()
	}
}

func bashCompletionInstallPath(homeDir string) string {
	return filepath.Join(homeDir, ".config", "agent-sessions", "bash-completion.bash")
}

func bashProfilePath(homeDir string) string {
	return filepath.Join(homeDir, ".bash_profile")
}

func normalizeCompletionContent(content []byte) string {
	return strings.ReplaceAll(string(content), "\r\n", "\n")
}

func ensureProfileSourcesCompletion(homeDir string, dryRun bool) {
	profilePath := bashProfilePath(homeDir)

	existing, err := os.ReadFile(profilePath)
	profileExists := err == nil
	if err != nil && !os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "error: reading %s: %v\n", profilePath, err)
		os.Exit(1)
	}

	content := ""
	if profileExists {
		content = string(existing)
	}

	if strings.Contains(content, profileSourceSubstring) {
		return
	}

	if dryRun {
		if profileExists {
			fmt.Printf("would update bash profile: %s\n", profilePath)
		}
		return
	}

	var newContent string
	if profileExists {
		newContent = content
		if len(newContent) > 0 && !strings.HasSuffix(newContent, "\n") {
			newContent += "\n"
		}
		newContent += "\n" + profileSourceBlock
	} else {
		newContent = profileSourceBlock
	}

	if err := os.WriteFile(profilePath, []byte(newContent), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot write %s: %v\n", profilePath, err)
		os.Exit(1)
	}
	fmt.Printf("updated bash profile: %s\n", profilePath)
}

func installBashCompletion(dryRun bool) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot resolve home directory: %v\n", err)
		os.Exit(1)
	}

	targetPath := bashCompletionInstallPath(homeDir)
	existing, err := os.ReadFile(targetPath)
	if err != nil {
		if !os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "error: reading %s: %v\n", targetPath, err)
			os.Exit(1)
		}
		if dryRun {
			fmt.Printf("would install bash completion: %s\n", targetPath)
			ensureProfileSourcesCompletion(homeDir, true)
			return
		}
		if err := os.MkdirAll(filepath.Dir(targetPath), 0755); err != nil {
			fmt.Fprintf(os.Stderr, "error: cannot create directory %s: %v\n", filepath.Dir(targetPath), err)
			os.Exit(1)
		}
		if err := os.WriteFile(targetPath, bashCompletionScript, 0644); err != nil {
			fmt.Fprintf(os.Stderr, "error: cannot write %s: %v\n", targetPath, err)
			os.Exit(1)
		}
		fmt.Printf("installed bash completion: %s\n", targetPath)
		ensureProfileSourcesCompletion(homeDir, false)
		return
	}

	existingNorm := normalizeCompletionContent(existing)
	scriptNorm := normalizeCompletionContent(bashCompletionScript)

	if existingNorm == scriptNorm {
		if dryRun {
			fmt.Printf("bash completion up to date (dry-run): %s\n", targetPath)
		} else {
			fmt.Printf("bash completion up to date: %s\n", targetPath)
		}
		ensureProfileSourcesCompletion(homeDir, dryRun)
		return
	}

	if dryRun {
		fmt.Printf("would update bash completion: %s\n", targetPath)
		ensureProfileSourcesCompletion(homeDir, true)
		return
	}

	if err := os.WriteFile(targetPath, bashCompletionScript, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "error: cannot write %s: %v\n", targetPath, err)
		os.Exit(1)
	}
	fmt.Printf("updated bash completion: %s\n", targetPath)
	ensureProfileSourcesCompletion(homeDir, false)
}

func cmdIntegrationsBashCompletions(args []string) {
	var install bool
	var dryRun bool

	_, err := lessflags.Bool("--install", &install).
		Bool("--dry-run", &dryRun).
		HelpFunc("-h,--help", printBashCompletionsHelp).
		Parse(args)

	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if !install {
		printBashCompletionsHelp()
		return
	}

	installBashCompletion(dryRun)
}
package server

import (
	"fmt"
	"os"
	"os/exec"

	iterm2 "github.com/xhd2015/dot-pkgs/go-pkgs/shell/iterm2"
)

const defaultCodeBinary = "/usr/local/bin/code"

func openInVSCode(dir string) error {
	binary := os.Getenv("AGENT_SESSIONS_CODE_BINARY")
	if binary == "" {
		binary = defaultCodeBinary
	}
	cmd := exec.Command(binary, dir)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("open in vscode: %w", err)
	}
	return nil
}

func openInIterm2(dir string) error {
	if err := iterm2.OpenConfig(dir, &iterm2.Config{
		Mode: iterm2.ModeReuseCurrent,
		Installed: func() bool {
			// Respect test env var override
			switch os.Getenv("KOOL_ITERM2_INSTALLED") {
			case "1":
				return true
			case "0":
				return false
			}
			return iterm2.IsInstalled()
		},
	}); err != nil {
		return fmt.Errorf("open in iterm2: %w", err)
	}
	return nil
}

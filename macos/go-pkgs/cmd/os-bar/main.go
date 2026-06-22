package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	lessflags "github.com/xhd2015/less-flags"
	"github.com/xhd2015/os-bar/macos/go-pkgs/monitor"
	"github.com/xhd2015/os-bar/macos/go-pkgs/server"
)

const (
	defaultPort = 38270
	defaultHost = "127.0.0.1"
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	subcommand := os.Args[1]
	args := os.Args[2:]

	switch subcommand {
	case "serve":
		if err := server.RunServe(args); err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
	case "metrics":
		cmdMetrics(args)
	case "-h", "--help":
		printUsage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand: %s\n", subcommand)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Print(`Usage: os-bar-daemon <command> [flags]

Commands:
  serve     Start the HTTP metrics daemon
  metrics   Fetch metrics from the running daemon

Run 'os-bar-daemon <command> --help' for more details.
`)
}

func serverURL(path string) string {
	return fmt.Sprintf("http://%s:%d%s", defaultHost, defaultPort, path)
}

func cmdMetrics(args []string) {
	var jsonOut bool

	helpText := `Usage: os-bar-daemon metrics [flags]

Fetch CPU, memory, and swap metrics from the running daemon.

Flags:
  --json      output raw JSON
  -h, --help  show help
`

	_, err := lessflags.Bool("--json", &jsonOut).
		Help("-h,--help", helpText).
		Parse(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(serverURL("/api/metrics"))
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: daemon unreachable at %s: %v\n", serverURL("/api/metrics"), err)
		os.Exit(1)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: read response: %v\n", err)
		os.Exit(1)
	}

	if resp.StatusCode != http.StatusOK {
		fmt.Fprintf(os.Stderr, "error: server returned status %d: %s\n", resp.StatusCode, string(body))
		os.Exit(1)
	}

	if jsonOut {
		fmt.Println(string(body))
		return
	}

	var metrics struct {
		CPUPercent     float64 `json:"cpu_percent"`
		CPUCores       int     `json:"cpu_cores"`
		MEMPercent     float64 `json:"mem_percent"`
		MemTotalBytes  uint64  `json:"mem_total_bytes"`
		MemUsedBytes   uint64  `json:"mem_used_bytes"`
		SwapTotalBytes uint64  `json:"swap_total_bytes"`
		SwapUsedBytes  uint64  `json:"swap_used_bytes"`
	}
	if err := json.Unmarshal(body, &metrics); err != nil {
		fmt.Fprintf(os.Stderr, "error: parse metrics: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("CPU: %s\n", monitor.FormatCPUDisplay(metrics.CPUPercent, metrics.CPUCores))
	fmt.Printf("Memory: %s\n", monitor.FormatMemDisplay(metrics.MemTotalBytes, metrics.MemUsedBytes))
	fmt.Printf("Swap: %s\n", monitor.FormatSwapDisplay(metrics.SwapTotalBytes, metrics.SwapUsedBytes))
}
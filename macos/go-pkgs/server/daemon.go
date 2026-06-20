package server

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"syscall"
	"time"

	lessflags "github.com/xhd2015/less-flags"
	"github.com/xhd2015/os-bar/macos/go-pkgs/monitor"
)

const defaultPort = 38270

// RunServe parses serve subcommand flags and runs the HTTP daemon.
// Returns nil when an existing healthy daemon is already running (singleton exit 0).
func RunServe(args []string) error {
	var port int = defaultPort
	var stateDirFlag string
	var mockMetrics bool

	helpText := `Usage: os-bar-daemon serve [flags]

Start the os-bar metrics HTTP daemon.

Flags:
  --port N           listen port (default: 38270)
  --state-dir DIR    state directory (default: $HOME/.os-bar/os-bar)
  --mock-metrics     use deterministic mock metrics provider
  -h, --help         show help
`

	_, err := lessflags.Int("--port", &port).
		String("--state-dir", &stateDirFlag).
		Bool("--mock-metrics", &mockMetrics).
		Help("-h,--help", helpText).
		Parse(args)
	if err != nil {
		return err
	}

	stateDir, err := ResolveStateDir(stateDirFlag)
	if err != nil {
		return fmt.Errorf("resolve state dir: %w", err)
	}

	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return fmt.Errorf("mkdir state dir: %w", err)
	}

	if trySingletonExit(stateDir, port) {
		return nil
	}

	var provider monitor.MetricsProvider
	var mock *monitor.MockProvider
	if mockMetrics {
		mock = monitor.NewMockProvider()
		provider = mock
	} else {
		provider = monitor.NewRealProvider()
	}

	srv := &daemon{
		port:     port,
		mockMode: mockMetrics,
		provider: provider,
		mock:     mock,
	}

	return srv.run(stateDir)
}

// ResolveStateDir resolves the daemon state directory from flag or environment.
func ResolveStateDir(flagValue string) (string, error) {
	if flagValue != "" {
		return flagValue, nil
	}
	if env := os.Getenv("OS_BAR_STATE_DIR"); env != "" {
		return env, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".os-bar", "os-bar"), nil
}

func (d *daemon) run(stateDir string) error {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", d.handleHealth)
	mux.HandleFunc("/api/metrics", d.handleMetrics)
	mux.HandleFunc("/api/info", d.handleInfo)
	mux.HandleFunc("/api/test/advance-tick", d.handleAdvanceTick)
	mux.HandleFunc("/", d.handleNotFound)

	addr := fmt.Sprintf("127.0.0.1:%d", d.port)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", addr, err)
	}

	pidPath := filepath.Join(stateDir, "daemon.pid")
	if err := os.WriteFile(pidPath, []byte(strconv.Itoa(os.Getpid())), 0644); err != nil {
		return fmt.Errorf("write pid file: %w", err)
	}

	httpServer := &http.Server{Handler: mux}
	go func() {
		if err := httpServer.Serve(listener); err != nil && err != http.ErrServerClosed {
			fmt.Fprintf(os.Stderr, "server error: %v\n", err)
		}
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
	<-sigCh

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_ = httpServer.Shutdown(ctx)
	_ = os.Remove(pidPath)
	return nil
}
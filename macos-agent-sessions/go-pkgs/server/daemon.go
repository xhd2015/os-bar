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
)

const defaultPort = 38271

// RunServe parses serve subcommand flags and runs the HTTP daemon.
// Returns nil when an existing healthy daemon is already running (singleton exit 0).
func RunServe(args []string) error {
	var port int = defaultPort
	var stateDirFlag string

	helpText := `Usage: agent-sessions serve [flags]

Start the agent-sessions HTTP daemon.

Flags:
  --port N         listen port (default: 38271)
  --state-dir DIR  state directory (default: $HOME/.os-bar/agent-sessions)
  -h, --help       show help
`

	_, err := lessflags.Int("--port", &port).
		String("--state-dir", &stateDirFlag).
		Help("-h,--help", helpText).
		Parse(args)
	if err != nil {
		return err
	}

	stateDir, err := ResolveStateDir(stateDirFlag)
	if err != nil {
		return fmt.Errorf("resolve state dir: %w", err)
	}

	if trySingletonExit(stateDir, port) {
		return nil
	}

	store, err := newStore(stateDir)
	if err != nil {
		return fmt.Errorf("init store: %w", err)
	}

	srv := &daemon{
		port:     port,
		stateDir: stateDir,
		store:    store,
	}

	return srv.run()
}

func (d *daemon) run() error {
	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", d.handleHealth)
	mux.HandleFunc("/api/list", d.handleList)
	mux.HandleFunc("/api/info", d.handleInfo)
	mux.HandleFunc("/api/logs", d.handleLogs)
	mux.HandleFunc("/api/notify", d.handleNotify)
	mux.HandleFunc("/api/events", d.handleEvents)
	mux.HandleFunc("/api/events/consume", d.handleConsume)
	mux.HandleFunc("/api/events/consume-all", d.handleConsumeAll)
	mux.HandleFunc("/api/integrations", d.handleIntegrations)
	mux.HandleFunc("/api/integrations/install", d.handleIntegrationsInstall)
	mux.HandleFunc("/", d.handleNotFound)

	addr := fmt.Sprintf("127.0.0.1:%d", d.port)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", addr, err)
	}

	pidPath := filepath.Join(d.stateDir, "daemon.pid")
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

	// Remove pid file before graceful shutdown so quit targets and health
	// checks do not observe a live pid after the process begins stopping.
	_ = os.Remove(pidPath)

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	_ = httpServer.Shutdown(ctx)
	return nil
}
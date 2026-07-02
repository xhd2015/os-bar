package server

import (
	"encoding/json"
	"os"
	"path/filepath"
)

const (
	configFileName       = "config.json"
	defaultOpenMethod    = "vscode"
	openMethodVSCode     = "vscode"
	openMethodIterm2     = "iterm2"
)

// Config represents the daemon's persisted configuration.
type Config struct {
	OpenMethod string `json:"open_method"`
}

func isValidOpenMethod(method string) bool {
	return method == openMethodVSCode || method == openMethodIterm2
}

func (d *daemon) loadConfig() (*Config, error) {
	path := filepath.Join(d.stateDir, configFileName)
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &Config{OpenMethod: defaultOpenMethod}, nil
		}
		return nil, err
	}
	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	if cfg.OpenMethod == "" {
		cfg.OpenMethod = defaultOpenMethod
	}
	return &cfg, nil
}

func (d *daemon) saveConfig(cfg *Config) error {
	path := filepath.Join(d.stateDir, configFileName)
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

# os-bar

macOS menu bar system monitor — shows CPU and memory usage directly in the menu bar.

Native SwiftUI app. No Electron.

## Features

- Live CPU% and Memory% in the menu bar
- SF Symbol icons (`cpu` / `memorychip`)
- Switch which metric to show in the bar (persisted)
- 10-second auto-refresh
- macOS 13+ (Ventura and later)

## Quick Start

```sh
./macos/script/dev.sh
```

## Distribution

```sh
./macos/script/bundle.sh   # → macos/os-bar.dmg
```

Open the `.dmg`, drag `os-bar.app` to `/Applications`.

## Project Layout

```
macos/                  # macOS app (SwiftUI + SwiftPM)
├── os-bar/             # App source
├── os-barTests/        # Test helper
├── tests/              # Doc-style tests
├── script/
│   ├── dev.sh          # Build & run
│   └── bundle.sh       # Build .app + .dmg
└── Package.swift
```

# Manual UI Verification

These tests require manual observation and interaction. No automated assertions.

## How to Run

1. Build the app: `cd macos && xcodebuild build -scheme os-bar`
2. Launch the app from the build output or Xcode.
3. Observe the menu bar and perform the checks below.

---

## Test 1: Menu Bar Rendering

### Steps
1. Launch the `os-bar` app.
2. Look at the macOS menu bar (top-right area).

### Expected
- Two groups appear in the menu bar, side by side:
  - An SF Symbol `cpu` icon followed by text like `XX%` (e.g., `45%`).
  - An SF Symbol `memorychip` icon followed by text like `XX%` (e.g., `73%`).
- The percentage text updates periodically (approximately every 10 seconds when using live data).
- Icons and text are clearly visible (not clipped, not overlapping).

---

## Test 2: Quit Terminates App

### Steps
1. Click on one of the menu bar items (CPU or MEM group).
2. Observe the dropdown menu that appears.
3. Click the **Quit** menu item.

### Expected
- Clicking the menu bar item opens a dropdown menu.
- The dropdown contains a "Quit" (or "Quit os-bar") option.
- Clicking Quit causes the menu bar items to disappear.
- The app process is no longer running (verify via Activity Monitor or `ps aux | grep os-bar`).

---

## Test 3: Menu Bar Click — Menu Content

### Steps
1. Click on the CPU menu bar item.
2. Observe the dropdown content.

### Expected
- The dropdown displays the current CPU and MEM percentages in human-readable form.
- May include additional information like "CPU: 45.2%", "Memory: 72.8%".
- The Quit button/option is present at the bottom of the menu.

---

## Test 4: Dark Mode Compatibility

### Steps
1. Switch macOS to Dark Mode (System Settings → Appearance → Dark).
2. Observe the menu bar icons and text.

### Expected
- SF Symbols and text remain visible and legible in Dark Mode.
- Colors adapt appropriately (SF Symbols use the system tint automatically).

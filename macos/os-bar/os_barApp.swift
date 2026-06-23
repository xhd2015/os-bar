import SwiftUI
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    weak var monitor: SystemMonitor?

    func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        monitor?.terminateDaemon()
    }
}

enum BarMetric: String, CaseIterable {
    case cpu
    case mem
}

@main
struct os_barApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = SystemMonitor()
    @AppStorage("barMetric") private var barMetric: BarMetric = .cpu
    @AppStorage("autoStart") private var autoStart = false

    init() {
        let monitor = SystemMonitor()
        _monitor = StateObject(wrappedValue: monitor)
        appDelegate.monitor = monitor
        // Sync toggle with actual system state
        if #available(macOS 13.0, *) {
            _autoStart.wrappedValue = SMAppService.mainApp.status == .enabled
        }
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 4) {
                Text("CPU: \(monitor.cpuDisplay)")
                Text("Memory: \(monitor.memDisplay)")
                Text("Swap: \(monitor.swapDisplay)")
                Text("Disk: \(monitor.diskDisplay)")

                Divider()

                Picker("Show in menu bar", selection: $barMetric) {
                    Text("CPU").tag(BarMetric.cpu)
                    Text("Memory").tag(BarMetric.mem)
                }
                .pickerStyle(.inline)

                Divider()

                Toggle("Auto Start", isOn: $autoStart)
                    .onChange(of: autoStart) { enabled in
                        if #available(macOS 13.0, *) {
                            do {
                                if enabled {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print("Auto Start toggle failed: \(error)")
                                autoStart = !enabled
                            }
                        }
                    }

                Divider()

                Button("Quit os-bar") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: barMetric == .cpu ? "cpu" : "memorychip")
                    .imageScale(.small)
                Text(String(format: "%d%%",
                    Int((barMetric == .cpu
                        ? monitor.cpuPercent
                        : monitor.memPercent).rounded())))
            }
            .font(.system(size: 11))
            .fixedSize()
        }
    }
}

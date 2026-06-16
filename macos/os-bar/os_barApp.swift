import SwiftUI

enum BarMetric: String, CaseIterable {
    case cpu
    case mem
}

@main
struct os_barApp: App {
    @StateObject private var monitor = SystemMonitor()
    @AppStorage("barMetric") private var barMetric: BarMetric = .cpu

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 4) {
                Text("CPU: \(Int(monitor.cpuPercent.rounded()))%")
                Text("Memory: \(Int(monitor.memPercent.rounded()))%")

                Divider()

                Picker("Show in menu bar", selection: $barMetric) {
                    Text("CPU").tag(BarMetric.cpu)
                    Text("Memory").tag(BarMetric.mem)
                }
                .pickerStyle(.inline)

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

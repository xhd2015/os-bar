import SwiftUI

struct LogsViewerView: View {
    @StateObject private var viewModel = LogsViewModel()
    @State private var jsonSheetEntry: NotifyLogEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.red)
            }

            if viewModel.entries.isEmpty {
                Text("No log entries")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(viewModel.entries.reversed()) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LogsEntryFormatter.formatDisplayLine(for: entry))
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                            ForEach(LogsEntryFormatter.formatCommandDetails(for: entry), id: \.self) { line in
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            if entry.event != "command.executed", let command = entry.command {
                                Text(command.command)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        Button("JSON") {
                            jsonSheetEntry = entry
                        }
                        .accessibilityIdentifier("logs-entry-json-button")
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .accessibilityIdentifier("logs-window")
        .sheet(item: $jsonSheetEntry) { entry in
            LogEntryJSONSheet(entry: entry) {
                jsonSheetEntry = nil
            }
        }
        .onAppear {
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}

private struct LogEntryJSONSheet: View {
    let entry: NotifyLogEntry
    let onClose: () -> Void

    private var prettyJSON: String {
        (try? LogsEntryJSON.prettify(entry: entry)) ?? "{\"error\":\"failed to encode entry\"}"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(prettyJSON)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .accessibilityIdentifier("logs-entry-json-sheet")
            }
            .navigationTitle("Log Entry JSON")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
            }
        }
    }
}

extension NotifyLogEntry: Identifiable {
    var id: String {
        "\(timestamp.timeIntervalSince1970)-\(dir)-\(source)-\(event ?? "")"
    }
}
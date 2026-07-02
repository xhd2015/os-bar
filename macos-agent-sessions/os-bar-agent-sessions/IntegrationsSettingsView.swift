import SwiftUI

struct IntegrationsSettingsView: View {
    @StateObject private var viewModel = IntegrationsViewModel(global: true)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NotificationSettingsSection()

            Divider()

            DefaultOpenModeSection(viewModel: viewModel)

            Divider()

            Text("Integrations")
                .font(.headline)

            if let error = viewModel.lastError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            ForEach(viewModel.integrations) { item in
                IntegrationRowView(item: item) {
                    viewModel.install(target: item.id)
                }
            }

            if viewModel.isInstalling {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("integrations-window")
        .task {
            if ProcessInfo.processInfo.arguments.contains("-uiTestingOpenSettings") {
                while !DaemonReadiness.shared.isReady {
                    try? await Task.sleep(nanoseconds: 25_000_000)
                }
            }
            viewModel.refresh()
            viewModel.loadOpenModeConfig()
        }
    }
}

private struct NotificationSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.headline)

            Text("macOS controls how long session alerts stay visible. Open this app's notification settings to choose a style:")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            NotificationStyleButton(
                title: "Brief (Banner)",
                detail: "Disappears automatically after a few seconds"
            ) {
                NotificationSettingsOpener.open()
            }

            NotificationStyleButton(
                title: "Persistent (Alert)",
                detail: "Stays on screen until you click — recommended for agent sessions",
                recommended: true
            ) {
                NotificationSettingsOpener.open()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notification-settings-section")
    }
}

private struct NotificationStyleButton: View {
    let title: String
    let detail: String
    var recommended = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.body.weight(.medium))
                        if recommended {
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.forward.app")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("notification-style-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
        .help("Open System Settings → Notifications for this app")
    }
}

private struct IntegrationRowView: View {
    let item: IntegrationItem
    let onInstall: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(item.displayName)
                .frame(width: 90, alignment: .leading)
                .accessibilityHidden(true)

            Text(item.badgeTitle)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .clipShape(Capsule())
                .accessibilityElement()
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("integration-\(item.id)-status")
                .accessibilityLabel(item.badgeTitle)
                .accessibilityValue(item.badgeTitle)

            Text(item.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)

            if item.showsInstallButton {
                Button("Install", action: onInstall)
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("integration-\(item.id)-install")
                    .accessibilityAction {
                        onInstall()
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("integration-\(item.id)")
    }

    private var badgeColor: Color {
        switch item.status {
        case "missing": return .orange
        case "up_to_date": return .green
        case "outdated": return .yellow
        default: return .secondary
        }
    }
}

private struct DefaultOpenModeSection: View {
    @ObservedObject var viewModel: IntegrationsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Open Mode")
                .font(.headline)

            Text("Choose which app opens when you click a session in the menu bar or a notification:")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Open with", selection: $viewModel.openMethod) {
                Text("VSCode").tag("vscode")
                Text("iTerm2").tag("iterm2")
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("open-mode-picker")
            .onChange(of: viewModel.openMethod) { newValue in
                viewModel.saveOpenModeConfig(method: newValue)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("default-open-mode-section")
    }
}
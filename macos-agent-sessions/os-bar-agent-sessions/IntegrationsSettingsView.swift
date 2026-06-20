import SwiftUI

struct IntegrationsSettingsView: View {
    @StateObject private var viewModel = IntegrationsViewModel(global: true)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        .frame(minWidth: 560, minHeight: 280)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("integrations-window")
        .onAppear {
            viewModel.refresh()
        }
    }
}

private struct IntegrationRowView: View {
    let item: IntegrationItem
    let onInstall: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(item.displayName)
                .frame(width: 90, alignment: .leading)

            Text(item.badgeTitle)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .clipShape(Capsule())
                .accessibilityIdentifier("integration-\(item.id)-status")
                .accessibilityLabel(item.badgeTitle)

            Text(item.path)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if item.showsInstallButton {
                Button("Install", action: onInstall)
                    .accessibilityIdentifier("integration-\(item.id)-install")
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
#if canImport(SwiftUI)
import SwiftUI

struct MemorySettingsView: View {
    @EnvironmentObject private var model: ProjectMirrorDashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderStrip(title: "RAM Limits", subtitle: model.ram.map { "\(MemoryFormatter.megabytes($0.freeMb)) free now" } ?? model.status)

            HStack(alignment: .top, spacing: 16) {
                RamGauge(ram: model.ram)
                    .padding(22)
                    .background(MirrorTheme.panel.fill(MirrorTheme.surface))
                    .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))

                VStack(alignment: .leading, spacing: 18) {
                    Picker("Profile", selection: $model.selectedProfile) {
                        Text("Quality").tag("quality")
                        Text("Balanced").tag("balanced")
                        Text("Performance").tag("performance")
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("RAM limit", systemImage: "memorychip")
                            Spacer()
                            Text(MemoryFormatter.megabytes(Int(model.ramLimitMb)))
                                .monospacedDigit()
                        }
                        Slider(value: $model.ramLimitMb, in: 512...32768, step: 256)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Low RAM alert", systemImage: "exclamationmark.triangle")
                            Spacer()
                            Text(MemoryFormatter.megabytes(Int(model.lowRamAlertMb)))
                                .monospacedDigit()
                        }
                        Slider(value: $model.lowRamAlertMb, in: 256...16384, step: 128)
                    }

                    Toggle(isOn: $model.notificationsEnabled) {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                    .toggleStyle(.switch)

                    HStack {
                        Button {
                            Task { await model.saveRuntime() }
                        } label: {
                            Label("Save", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            Task { await model.refreshAll() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh")
                    }
                }
                .padding(16)
                .background(MirrorTheme.panel.fill(MirrorTheme.surface))
                .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))
            }

            AlertListView(alerts: model.alerts)
            Spacer(minLength: 0)
        }
    }
}

private struct AlertListView: View {
    var alerts: [AlertInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Alerts")
                .font(.headline)
                .foregroundStyle(MirrorTheme.text)
            if alerts.isEmpty {
                Text("No active alerts")
                    .foregroundStyle(MirrorTheme.muted)
            } else {
                ForEach(alerts) { alert in
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(MirrorTheme.danger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.title)
                                .foregroundStyle(MirrorTheme.text)
                            Text(alert.message)
                                .foregroundStyle(MirrorTheme.muted)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .background(MirrorTheme.panel.fill(MirrorTheme.surface))
        .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))
    }
}
#endif

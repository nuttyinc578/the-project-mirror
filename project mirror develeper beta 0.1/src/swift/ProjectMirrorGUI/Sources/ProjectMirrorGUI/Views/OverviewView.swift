#if canImport(SwiftUI)
import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var model: ProjectMirrorDashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HeaderStrip(title: model.config?.name ?? ProjectMirrorCore.projectName, subtitle: model.status)

            HStack(alignment: .top, spacing: 16) {
                RamGauge(ram: model.ram)
                    .padding(22)
                    .background(MirrorTheme.panel.fill(MirrorTheme.surface))
                    .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    MetricCard(
                        title: "Free RAM",
                        value: model.ram.map { MemoryFormatter.megabytes($0.freeMb) } ?? "--",
                        detail: "Limit \(model.ram.map { MemoryFormatter.megabytes($0.ramLimitMb) } ?? "--")",
                        systemImage: "memorychip",
                        tint: MirrorTheme.primary
                    )
                    MetricCard(
                        title: "Profile",
                        value: model.selectedProfile.capitalized,
                        detail: "Runtime mode shared by Ruby, Node, Python, .NET, and Swift",
                        systemImage: "slider.horizontal.3",
                        tint: MirrorTheme.accent
                    )
                    MetricCard(
                        title: "Alerts",
                        value: "\(model.alerts.count)",
                        detail: model.alerts.first?.message ?? "No active RAM alerts",
                        systemImage: model.alerts.isEmpty ? "checkmark.shield" : "exclamationmark.triangle",
                        tint: model.alerts.isEmpty ? MirrorTheme.primary : MirrorTheme.danger
                    )
                    MetricCard(
                        title: "Tasks",
                        value: "\(model.tasks.count)",
                        detail: "Showing highest memory processes from Node bridge",
                        systemImage: "list.bullet.rectangle",
                        tint: Color.cyan
                    )
                }
            }

            TopTasksPreview(tasks: TaskManagerCore.topMemoryTasks(model.tasks, limit: 6))
            Spacer(minLength: 0)
        }
    }
}

struct HeaderStrip: View {
    var title: String
    var subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(MirrorTheme.text)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(MirrorTheme.muted)
                    .lineLimit(2)
            }
            Spacer()
        }
    }
}

struct TopTasksPreview: View {
    var tasks: [TaskInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Memory Pressure")
                .font(.headline)
                .foregroundStyle(MirrorTheme.text)
            ForEach(tasks) { task in
                HStack(spacing: 10) {
                    Text(task.name)
                        .foregroundStyle(MirrorTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Text(MemoryFormatter.megabytes(task.memoryMb))
                        .foregroundStyle(MirrorTheme.muted)
                        .monospacedDigit()
                }
                .font(.callout)
            }
        }
        .padding(14)
        .background(MirrorTheme.panel.fill(MirrorTheme.surface))
        .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))
    }
}
#endif

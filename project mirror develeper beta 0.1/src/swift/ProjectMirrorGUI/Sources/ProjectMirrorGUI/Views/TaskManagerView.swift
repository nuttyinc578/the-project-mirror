#if canImport(SwiftUI)
import SwiftUI

struct TaskManagerView: View {
    @EnvironmentObject private var model: ProjectMirrorDashboardModel
    @State private var pendingEndTask: TaskInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderStrip(title: "Task Manager", subtitle: "\(model.tasks.count) processes sorted by memory")

            ScrollView {
                LazyVStack(spacing: 8) {
                    TaskHeaderRow()
                    ForEach(model.tasks) { task in
                        TaskRow(task: task) {
                            pendingEndTask = task
                        }
                    }
                }
            }
            .background(MirrorTheme.panel.fill(MirrorTheme.surface))
            .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))
        }
        .confirmationDialog(
            "End task",
            isPresented: Binding(
                get: { pendingEndTask != nil },
                set: { if !$0 { pendingEndTask = nil } }
            ),
            presenting: pendingEndTask
        ) { task in
            Button("End \(task.name)", role: .destructive) {
                Task { await model.endTask(task) }
            }
            Button("Cancel", role: .cancel) { pendingEndTask = nil }
        } message: { task in
            Text("PID \(task.pid)")
        }
    }
}

private struct TaskHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Process")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("PID")
                .frame(width: 72, alignment: .trailing)
            Text("Memory")
                .frame(width: 110, alignment: .trailing)
            Text("")
                .frame(width: 44)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(MirrorTheme.muted)
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
}

private struct TaskRow: View {
    var task: TaskInfo
    var onEnd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .foregroundStyle(MirrorTheme.text)
                    .lineLimit(1)
                Text(task.command)
                    .font(.caption)
                    .foregroundStyle(MirrorTheme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(task.pid)")
                .monospacedDigit()
                .foregroundStyle(MirrorTheme.muted)
                .frame(width: 72, alignment: .trailing)

            Text(MemoryFormatter.megabytes(task.memoryMb))
                .monospacedDigit()
                .foregroundStyle(MirrorTheme.text)
                .frame(width: 110, alignment: .trailing)

            Button(role: .destructive, action: onEnd) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("End task")
            .frame(width: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.025))
    }
}
#endif

#if canImport(SwiftUI)
import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case tasks = "Task Manager"
    case memory = "RAM Limits"
    case optimizer = "AI Optimizer"
    case bridge = "Bridge"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .tasks: return "list.bullet.rectangle"
        case .memory: return "memorychip"
        case .optimizer: return "sparkles"
        case .bridge: return "point.3.connected.trianglepath.dotted"
        }
    }
}

struct DashboardShellView: View {
    @EnvironmentObject private var model: ProjectMirrorDashboardModel
    @State private var selection: DashboardSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Mirror")
            .frame(minWidth: 220)
        } detail: {
            ZStack {
                MirrorTheme.background.ignoresSafeArea()
                currentView
                    .padding(22)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")

                    if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currentView: some View {
        switch selection ?? .overview {
        case .overview:
            OverviewView()
        case .tasks:
            TaskManagerView()
        case .memory:
            MemorySettingsView()
        case .optimizer:
            OptimizerView()
        case .bridge:
            BridgeStatusView()
        }
    }
}
#endif

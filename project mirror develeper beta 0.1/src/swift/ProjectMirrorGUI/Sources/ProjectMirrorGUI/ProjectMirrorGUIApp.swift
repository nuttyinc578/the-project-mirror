#if canImport(SwiftUI)
import SwiftUI

@main
struct ProjectMirrorGUIApp: App {
    @StateObject private var model = ProjectMirrorDashboardModel()

    var body: some Scene {
        WindowGroup {
            DashboardShellView()
                .environmentObject(model)
                .task {
                    await model.start()
                }
                .frame(minWidth: 1040, minHeight: 680)
        }
        .windowStyle(.titleBar)
    }
}
#endif

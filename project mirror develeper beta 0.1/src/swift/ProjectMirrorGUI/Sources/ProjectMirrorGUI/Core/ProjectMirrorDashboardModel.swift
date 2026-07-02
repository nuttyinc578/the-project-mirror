#if canImport(SwiftUI)
import SwiftUI

@MainActor
final class ProjectMirrorDashboardModel: ObservableObject {
    @Published var config: ProjectConfig?
    @Published var ram: MemorySnapshot?
    @Published var tasks: [TaskInfo] = []
    @Published var alerts: [AlertInfo] = []
    @Published var bridge: BridgeInfo?
    @Published var optimization: OptimizationPlan?
    @Published var selectedProfile = "balanced"
    @Published var ramLimitMb = 4096.0
    @Published var lowRamAlertMb = 1024.0
    @Published var notificationsEnabled = true
    @Published var isLoading = false
    @Published var status = "Ready"

    private let client = ProjectMirrorClient()
    private let notificationService = MirrorNotificationService()
    private var pollTask: Task<Void, Never>?
    private var deliveredAlertIds = Set<String>()

    func start() async {
        await notificationService.requestAuthorization()
        await refreshAll()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.refreshLiveData()
            }
        }
    }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let configValue = client.config()
            async let ramValue = client.ram()
            async let taskValue = client.tasks(limit: 80)
            async let alertValue = client.alerts()
            async let bridgeValue = client.health()

            let loadedConfig = try await configValue
            let loadedRam = try await ramValue
            let loadedTasks = try await taskValue
            let loadedAlerts = try await alertValue
            let loadedBridge = try await bridgeValue

            apply(config: loadedConfig)
            ram = loadedRam
            tasks = loadedTasks.tasks
            alerts = loadedAlerts.alerts
            bridge = loadedBridge
            status = "Connected"
            await deliverNewAlerts(loadedAlerts.alerts)
        } catch {
            status = "Bridge offline: \(error.localizedDescription)"
        }
    }

    func refreshLiveData() async {
        do {
            async let ramValue = client.ram()
            async let taskValue = client.tasks(limit: 80)
            async let alertValue = client.alerts()
            ram = try await ramValue
            let taskResponse = try await taskValue
            tasks = taskResponse.tasks.tasks
            let alertResponse = try await alertValue
            alerts = alertResponse.alerts
            await deliverNewAlerts(alertResponse.alerts)
            status = "Connected"
        } catch {
            status = "Bridge offline: \(error.localizedDescription)"
        }
    }

    func saveRuntime() async {
        do {
            let update = RuntimeUpdateRequest(
                profile: selectedProfile,
                ramLimitMb: Int(ramLimitMb),
                lowRamAlertMb: Int(lowRamAlertMb),
                notificationsEnabled: notificationsEnabled
            )
            let response = try await client.updateRuntime(update)
            apply(runtime: response.runtime)
            ram = response.ram
            alerts = response.alerts
            status = "Runtime saved"
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    func requestOptimization() async {
        isLoading = true
        defer { isLoading = false }
        do {
            optimization = try await client.optimize()
            status = "Optimization ready"
        } catch {
            status = "Optimization failed: \(error.localizedDescription)"
        }
    }

    func endTask(_ task: TaskInfo) async {
        do {
            try await client.endTask(pid: task.pid)
            tasks.removeAll { $0.pid == task.pid }
            status = "Ended \(task.name)"
        } catch {
            status = "End task failed: \(error.localizedDescription)"
        }
    }

    private func apply(config: ProjectConfig) {
        self.config = config
        apply(runtime: config.runtime)
    }

    private func apply(runtime: RuntimeSettings) {
        selectedProfile = runtime.profile
        ramLimitMb = Double(runtime.ramLimitMb)
        lowRamAlertMb = Double(runtime.lowRamAlertMb)
        notificationsEnabled = runtime.notificationsEnabled ?? true
    }

    private func deliverNewAlerts(_ alerts: [AlertInfo]) async {
        guard notificationsEnabled else { return }
        for alert in alerts where !deliveredAlertIds.contains(alert.id) {
            deliveredAlertIds.insert(alert.id)
            await notificationService.notify(alert: alert)
        }
    }
}
#endif


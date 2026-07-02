import Foundation

struct EndpointConfig: Codable, Hashable {
    var host: String
    var port: Int
}

struct RuntimeSettings: Codable, Hashable {
    var profile: String
    var ramLimitMb: Int
    var lowRamAlertMb: Int
    var pollSeconds: Int
    var notificationsEnabled: Bool?
    var msys2Compatible: Bool?
}

struct GuiSettings: Codable, Hashable {
    var refreshSeconds: Int
    var taskLimit: Int
    var notifications: Bool
}

struct ProjectConfig: Codable, Hashable {
    var name: String
    var version: String
    var server: EndpointConfig
    var aiApi: EndpointConfig
    var runtime: RuntimeSettings
    var gui: GuiSettings?
}

struct MemorySnapshot: Codable, Hashable {
    var totalMb: Int
    var freeMb: Int
    var usedMb: Int
    var usedPercent: Int
    var ramLimitMb: Int
    var lowRamAlertMb: Int
    var lowRam: Bool
}

struct TaskInfo: Codable, Identifiable, Hashable {
    var name: String
    var pid: Int
    var memoryMb: Int
    var cpuPercent: Double?
    var command: String

    var id: Int { pid }
}

struct TaskListResponse: Codable {
    var ok: Bool
    var tasks: [TaskInfo]
    var count: Int?
    var error: String?
    var ram: MemorySnapshot?
}

struct AlertInfo: Codable, Identifiable, Hashable {
    var id: String
    var severity: String
    var title: String
    var message: String
    var createdAt: String
}

struct AlertResponse: Codable {
    var ok: Bool
    var notificationsEnabled: Bool
    var ram: MemorySnapshot
    var alerts: [AlertInfo]
}

struct RuntimeUpdateRequest: Codable {
    var profile: String?
    var ramLimitMb: Int?
    var lowRamAlertMb: Int?
    var notificationsEnabled: Bool?
}

struct RuntimeUpdateResponse: Codable {
    var ok: Bool
    var runtime: RuntimeSettings
    var ram: MemorySnapshot
    var alerts: [AlertInfo]
}

struct BridgeInfo: Codable, Hashable {
    var ok: Bool
    var root: String
    var configPath: String
    var endpoints: [String: String]
    var commands: [String: String]
}

struct OptimizationPlan: Codable, Hashable {
    var ok: Bool?
    var project: String?
    var version: String?
    var source: String?
    var mode: String?
    var profile: String?
    var summary: [String]?
    var pythonApiWarning: String?
}

struct OptimizePayload: Codable {
    var mode: String
    var video: VideoTelemetry
    var gameplay: GameplayTelemetry
}

struct VideoTelemetry: Codable {
    var input: String
    var width: Int
    var height: Int
    var fps: Int
}

struct GameplayTelemetry: Codable {
    var currentFps: Int
    var targetFps: Int
    var latencyMs: Int
}

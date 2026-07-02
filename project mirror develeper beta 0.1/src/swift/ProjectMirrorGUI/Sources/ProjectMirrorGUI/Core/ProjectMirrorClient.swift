import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ProjectMirrorCore {
    static let defaultBaseURL = URL(string: "http://127.0.0.1:4971")!
    static let projectName = "Project Mirror Dev Beta 1"
}

struct HTTPStatusError: Error, CustomStringConvertible {
    var statusCode: Int
    var body: String

    var description: String {
        "HTTP \(statusCode): \(body)"
    }
}

actor ProjectMirrorClient {
    private let baseURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL = ProjectMirrorCore.defaultBaseURL) {
        self.baseURL = baseURL
    }

    func health() async throws -> BridgeInfo {
        try await get("/api/bridge")
    }

    func config() async throws -> ProjectConfig {
        try await get("/api/config")
    }

    func ram() async throws -> MemorySnapshot {
        try await get("/api/ram")
    }

    func alerts() async throws -> AlertResponse {
        try await get("/api/alerts")
    }

    func tasks(limit: Int = 60) async throws -> TaskListResponse {
        try await get("/api/tasks?limit=\(limit)")
    }

    func updateRuntime(_ request: RuntimeUpdateRequest) async throws -> RuntimeUpdateResponse {
        try await post("/api/runtime", body: request)
    }

    func endTask(pid: Int) async throws {
        let request = EndTaskRequest(pid: pid, confirm: "end-task")
        let _: EndTaskResponse = try await post("/api/tasks/end", body: request)
    }

    func optimize() async throws -> OptimizationPlan {
        let payload = OptimizePayload(
            mode: "auto",
            video: VideoTelemetry(input: "capture.mp4", width: 1920, height: 1080, fps: 60),
            gameplay: GameplayTelemetry(currentFps: 58, targetFps: 60, latencyMs: 42)
        )
        return try await post("/api/optimize", body: payload)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = URL(string: path, relativeTo: baseURL)!
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, Body: Encodable>(_ path: String, body: Body) async throws -> T {
        let url = URL(string: path, relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPStatusError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
    }
}

private struct EndTaskRequest: Codable {
    var pid: Int
    var confirm: String
}

private struct EndTaskResponse: Codable {
    var ok: Bool
    var pid: Int?
    var error: String?
}

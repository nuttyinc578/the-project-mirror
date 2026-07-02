import Foundation

struct MemoryFormatter {
    static func megabytes(_ value: Int) -> String {
        if value >= 1024 {
            let gb = Double(value) / 1024.0
            return String(format: "%.1f GB", gb)
        }
        return "\(value) MB"
    }

    static func percent(_ value: Int) -> String {
        "\(max(0, min(100, value)))%"
    }
}

struct TaskManagerCore {
    static func topMemoryTasks(_ tasks: [TaskInfo], limit: Int = 12) -> [TaskInfo] {
        Array(tasks.sorted { $0.memoryMb > $1.memoryMb }.prefix(limit))
    }
}

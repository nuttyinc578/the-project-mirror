#if !canImport(SwiftUI)
import Foundation

@main
struct ProjectMirrorFallbackMain {
    static func main() async {
        let client = ProjectMirrorClient()
        print("Project Mirror Dev Beta 1 Swift core")
        do {
            let config = try await client.config()
            let ram = try await client.ram()
            let tasks = try await client.tasks(limit: 8)
            print("Profile: \(config.runtime.profile)")
            print("RAM: \(MemoryFormatter.megabytes(ram.freeMb)) free / \(MemoryFormatter.megabytes(ram.totalMb)) total")
            print("Top tasks:")
            for task in tasks.tasks {
                print("  \(task.pid) \(task.name) \(MemoryFormatter.megabytes(task.memoryMb))")
            }
        } catch {
            print("Node bridge is offline or unreachable: \(error)")
        }
    }
}
#endif

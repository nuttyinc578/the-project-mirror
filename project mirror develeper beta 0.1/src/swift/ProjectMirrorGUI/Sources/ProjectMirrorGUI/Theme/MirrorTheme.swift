#if canImport(SwiftUI)
import SwiftUI

enum MirrorTheme {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.09)
    static let surface = Color(red: 0.12, green: 0.13, blue: 0.14)
    static let surfaceRaised = Color(red: 0.16, green: 0.17, blue: 0.18)
    static let primary = Color(red: 0.25, green: 0.78, blue: 0.72)
    static let accent = Color(red: 0.96, green: 0.67, blue: 0.25)
    static let danger = Color(red: 0.94, green: 0.31, blue: 0.31)
    static let text = Color(red: 0.94, green: 0.95, blue: 0.94)
    static let muted = Color(red: 0.62, green: 0.65, blue: 0.66)

    static let panel = RoundedRectangle(cornerRadius: 8, style: .continuous)
}
#endif

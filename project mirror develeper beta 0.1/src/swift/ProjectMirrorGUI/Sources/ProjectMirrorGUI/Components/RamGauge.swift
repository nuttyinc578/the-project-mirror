#if canImport(SwiftUI)
import SwiftUI

struct RamGauge: View {
    var ram: MemorySnapshot?

    private var usedFraction: Double {
        guard let ram, ram.totalMb > 0 else { return 0 }
        return Double(ram.usedMb) / Double(ram.totalMb)
    }

    private var ringColor: Color {
        guard let ram else { return MirrorTheme.primary }
        if ram.lowRam { return MirrorTheme.danger }
        if ram.usedPercent >= 80 { return MirrorTheme.accent }
        return MirrorTheme.primary
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 18)
            Circle()
                .trim(from: 0, to: usedFraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: usedFraction)
            VStack(spacing: 6) {
                Text(ram.map { MemoryFormatter.percent($0.usedPercent) } ?? "--")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(MirrorTheme.text)
                Text("RAM used")
                    .font(.caption)
                    .foregroundStyle(MirrorTheme.muted)
            }
        }
        .frame(width: 190, height: 190)
        .accessibilityLabel("RAM used")
    }
}
#endif

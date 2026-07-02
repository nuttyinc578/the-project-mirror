#if canImport(SwiftUI)
import SwiftUI

struct BridgeStatusView: View {
    @EnvironmentObject private var model: ProjectMirrorDashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderStrip(title: "Runtime Bridge", subtitle: model.bridge?.configPath ?? model.status)

            VStack(alignment: .leading, spacing: 14) {
                Text("Endpoints")
                    .font(.headline)
                    .foregroundStyle(MirrorTheme.text)
                ForEach((model.bridge?.endpoints.keys.sorted() ?? []), id: \.self) { key in
                    BridgeRow(label: key, value: model.bridge?.endpoints[key] ?? "")
                }
            }
            .padding(14)
            .background(MirrorTheme.panel.fill(MirrorTheme.surface))
            .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))

            VStack(alignment: .leading, spacing: 14) {
                Text("Commands")
                    .font(.headline)
                    .foregroundStyle(MirrorTheme.text)
                ForEach((model.bridge?.commands.keys.sorted() ?? []), id: \.self) { key in
                    BridgeRow(label: key, value: model.bridge?.commands[key] ?? "")
                }
            }
            .padding(14)
            .background(MirrorTheme.panel.fill(MirrorTheme.surface))
            .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))

            Spacer(minLength: 0)
        }
    }
}

private struct BridgeRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(MirrorTheme.muted)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .foregroundStyle(MirrorTheme.text)
                .textSelection(.enabled)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .font(.callout.monospaced())
    }
}
#endif

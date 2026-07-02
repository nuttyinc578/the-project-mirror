#if canImport(SwiftUI)
import SwiftUI

struct OptimizerView: View {
    @EnvironmentObject private var model: ProjectMirrorDashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderStrip(title: "AI Optimizer", subtitle: model.optimization?.source ?? model.status)

            HStack(spacing: 12) {
                Button {
                    Task { await model.requestOptimization() }
                } label: {
                    Label("Optimize", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)

                if let profile = model.optimization?.profile {
                    Text(profile.capitalized)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(MirrorTheme.primary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                if let warning = model.optimization?.pythonApiWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(MirrorTheme.accent)
                }

                ForEach(model.optimization?.summary ?? [], id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(MirrorTheme.primary)
                        Text(item)
                            .foregroundStyle(MirrorTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }

                if model.optimization == nil {
                    Text("Waiting for an optimization plan")
                        .foregroundStyle(MirrorTheme.muted)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MirrorTheme.panel.fill(MirrorTheme.surface))
            .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))

            Spacer(minLength: 0)
        }
    }
}
#endif

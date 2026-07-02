#if canImport(SwiftUI)
import SwiftUI

struct MetricCard: View {
    var title: String
    var value: String
    var detail: String
    var systemImage: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(MirrorTheme.muted)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(MirrorTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(detail)
                .font(.caption)
                .foregroundStyle(MirrorTheme.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(minHeight: 126, alignment: .topLeading)
        .background(MirrorTheme.panel.fill(MirrorTheme.surface))
        .overlay(MirrorTheme.panel.stroke(Color.white.opacity(0.07)))
    }
}
#endif

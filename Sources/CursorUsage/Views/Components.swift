import SwiftUI

extension UsageLevel {
    var tint: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

/// 圆角进度条,颜色按用量档位。
/// 进度很少时填充条至少露出一个圆头(宽度 = 条高),避免变成一根细线。
struct ProgressBar: View {
    let percent: Double?
    var height: CGFloat = 8

    var body: some View {
        let tint = UsageLevel(percent: percent).tint
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: Self.fillWidth(percent: percent, trackWidth: geo.size.width, height: height))
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.4), value: percent)
    }

    /// 0% 不画填充;有进度时不小于条高;最大为整条。
    static func fillWidth(percent: Double?, trackWidth: CGFloat, height: CGFloat) -> CGFloat {
        let fraction = max(0, min(1, (percent ?? 0) / 100))
        guard fraction > 0 else { return 0 }
        return min(trackWidth, max(height, fraction * trackWidth))
    }
}

/// 重置时间 + 实时倒计时,如 "11月10日 15:19 · 1分钟"。弹窗开着时每 15 秒更新一次。
struct ResetRow: View {
    let title: String
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            InfoRow(title, "\(date.formatted(.dateTime.month().day().hour().minute())) · "
                    + Fmt.remaining(date.timeIntervalSince(context.date)))
        }
    }
}

/// 左标题、右数值的一行
struct InfoRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }
}

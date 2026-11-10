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

/// 圆角进度条,颜色按用量档位
struct ProgressBar: View {
    let percent: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(UsageLevel(percent: percent).tint)
                    .frame(width: max(0, min(1, (percent ?? 0) / 100)) * geo.size.width)
            }
        }
        .frame(height: 8)
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

import Foundation

enum Fmt {
    static func dollars(cents: Double?) -> String {
        guard let cents else { return "--" }
        return String(format: "$%.2f", cents / 100)
    }

    /// tokens 数量的紧凑写法:950 / 12.3K / 4.9M / 1.2B
    static func tokens(_ n: Double) -> String {
        switch n {
        case ..<1_000: return String(Int(n))
        case ..<1_000_000: return String(format: "%.1fK", n / 1_000)
        case ..<1_000_000_000: return String(format: "%.1fM", n / 1_000_000)
        default: return String(format: "%.2fB", n / 1_000_000_000)
        }
    }

    /// 输入/输出/缓存的拆分说明:输入 4.9M · 输出 0.7M · 缓存 87.0M
    static func tokenBreakdown(_ u: TokenUsage) -> String {
        "输入 \(tokens(u.input)) · 输出 \(tokens(u.output)) · 缓存 \(tokens(u.cache))"
    }

    /// 距重置的剩余时间,精确到分钟:2天3小时 / 5小时12分钟 / 1分钟
    static func remaining(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        if s <= 0 { return "已到重置时间" }
        let d = s / 86_400, h = (s % 86_400) / 3_600, m = (s % 3_600) / 60
        if d > 0 { return h > 0 ? "\(d)天\(h)小时" : "\(d)天" }
        if h > 0 { return m > 0 ? "\(h)小时\(m)分钟" : "\(h)小时" }
        return m > 0 ? "\(m)分钟" : "不到1分钟"
    }

    /// 整数百分比,用于菜单栏:91%
    static func percent(_ p: Double?) -> String {
        guard let p else { return "--" }
        return "\(Int(p.rounded()))%"
    }

    /// 一位小数百分比,用于弹窗和通知:91.1%
    static func percent1(_ p: Double?) -> String {
        guard let p else { return "--" }
        return String(format: "%.1f%%", p)
    }
}

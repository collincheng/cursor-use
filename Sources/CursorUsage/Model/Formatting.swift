import Foundation

enum Fmt {
    static func dollars(cents: Double?) -> String {
        guard let cents else { return "--" }
        return String(format: "$%.2f", cents / 100)
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

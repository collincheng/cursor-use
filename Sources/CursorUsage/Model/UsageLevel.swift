import Foundation

/// 用量所处的档位,由设置里的警告线/严重线决定。
enum UsageLevel: Int, Comparable {
    case normal = 0
    case warning
    case critical

    init(percent: Double?) {
        guard let p = percent else { self = .normal; return }
        if p >= Pref.crit { self = .critical }
        else if p >= Pref.warn { self = .warning }
        else { self = .normal }
    }

    static func < (a: UsageLevel, b: UsageLevel) -> Bool { a.rawValue < b.rawValue }
}

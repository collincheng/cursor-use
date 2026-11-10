import Foundation

/// UserDefaults 键与读取入口。SwiftUI 里用 @AppStorage(Pref.xxx) 绑定同一个键。
enum Pref {
    static let refreshMinutes = "refreshMinutes"
    static let warnThreshold = "warnThreshold"
    static let critThreshold = "critThreshold"
    static let menuBarMode = "menuBarMode"                  // MetricMode.rawValue
    static let notificationsEnabled = "notificationsEnabled"

    private static let versionKey = "prefsVersion"
    private static let currentVersion = 2

    static func register() {
        let d = UserDefaults.standard
        d.register(defaults: [
            refreshMinutes: 5,
            warnThreshold: 80,
            critThreshold: 90,
            menuBarMode: MetricMode.api.rawValue,
            notificationsEnabled: true,
        ])
        migrate(d)
        // 已移除的"每增长 N% 提醒"功能留下的设置
        for key in ["stepNotifyEnabled", "stepPercent", "stepBaseline"] { d.removeObject(forKey: key) }
    }

    /// v2:显示指标改为 API 用量。
    /// 旧版本会把默认值 "percent"(总用量)写进设置,那不是用户的主动选择,所以直接重置。
    private static func migrate(_ d: UserDefaults) {
        if d.integer(forKey: versionKey) < currentVersion {
            d.set(MetricMode.api.rawValue, forKey: menuBarMode)
            d.set(currentVersion, forKey: versionKey)
        }
    }

    static var metricMode: MetricMode {
        MetricMode(rawValue: UserDefaults.standard.string(forKey: menuBarMode) ?? "") ?? .api
    }
    static var refreshInterval: TimeInterval {
        TimeInterval(max(1, UserDefaults.standard.integer(forKey: refreshMinutes))) * 60
    }
    static var warn: Double { Double(UserDefaults.standard.integer(forKey: warnThreshold)) }
    static var crit: Double { Double(UserDefaults.standard.integer(forKey: critThreshold)) }
    static var notifications: Bool { UserDefaults.standard.bool(forKey: notificationsEnabled) }

    /// 警告线必须比严重线低至少 5 个点,否则档位判断会失效。返回修正后的警告线。
    static func clampWarn(_ warn: Int, crit: Int) -> Int {
        max(10, min(warn, crit - 5))
    }

    /// 严重线不能低于警告线 + 5,也不能超过 100。返回修正后的严重线。
    static func clampCrit(_ crit: Int, warn: Int) -> Int {
        min(100, max(crit, warn + 5))
    }
}

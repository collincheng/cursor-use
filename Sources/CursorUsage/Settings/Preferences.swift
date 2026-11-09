import Foundation

/// UserDefaults 键与读取入口。SwiftUI 里用 @AppStorage(Pref.xxx) 绑定同一个键。
enum Pref {
    static let refreshMinutes = "refreshMinutes"
    static let warnThreshold = "warnThreshold"
    static let critThreshold = "critThreshold"
    static let menuBarMode = "menuBarMode"                  // MetricMode.rawValue
    static let notificationsEnabled = "notificationsEnabled"
    static let stepNotifyEnabled = "stepNotifyEnabled"      // 每增长 N% 提醒
    static let stepPercent = "stepPercent"

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
            stepNotifyEnabled: true,
            stepPercent: 2.0,
        ])
        migrate(d)
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
    static var stepNotify: Bool { UserDefaults.standard.bool(forKey: stepNotifyEnabled) }
    static var step: Double { max(0.1, UserDefaults.standard.double(forKey: stepPercent)) }
}

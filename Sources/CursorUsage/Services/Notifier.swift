import Foundation
import UserNotifications

/// 阈值通知:"显示指标"(默认 API 用量)越过警告线/严重线时提醒,同一账期每一档只发一次。
final class Notifier {
    static let shared = Notifier()

    private let levelKey = "notifiedLevel"
    private let cycleKey = "notifiedCycle"

    /// 通知只在以 .app 运行时可用
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluate(_ snap: UsageSnapshot) {
        let mode = Pref.metricMode
        guard let p = snap.percent(for: mode) else { return }
        let d = UserDefaults.standard

        // 新账期:重置已通知的档位
        let cycle = snap.cycleEnd?.timeIntervalSince1970 ?? 0
        if d.double(forKey: cycleKey) != cycle {
            d.set(cycle, forKey: cycleKey)
            d.set(UsageLevel.normal.rawValue, forKey: levelKey)
        }

        let level = UsageLevel(percent: p)
        let stored = UsageLevel(rawValue: d.integer(forKey: levelKey)) ?? .normal

        if level < stored {
            d.set(level.rawValue, forKey: levelKey)   // 用量回落(或切换了指标)后重新允许提醒
            return
        }
        guard level > stored else { return }

        d.set(level.rawValue, forKey: levelKey)
        guard Pref.notifications else { return }

        let title = level == .critical ? "Cursor \(mode.label)即将耗尽" : "Cursor \(mode.label)提醒"
        send(id: "level-\(level.rawValue)", title: title, body: body(mode: mode, percent: p, resetIn: snap.resetCountdown))
    }

    // MARK: 发送

    private func body(mode: MetricMode, percent: Double, resetIn: String?) -> String {
        var s = "\(mode.label)已达 \(Fmt.percent1(percent))"
        if let r = resetIn { s += ",距重置还有 \(r)" }
        return s
    }

    private func send(id: String, title: String, body: String) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // 每次用唯一 id,避免新通知覆盖上一条而看不出来
        let req = UNNotificationRequest(identifier: "\(id)-\(Date().timeIntervalSince1970)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

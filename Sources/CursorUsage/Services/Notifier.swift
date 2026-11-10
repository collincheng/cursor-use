import Foundation
import UserNotifications

/// 两类通知,都基于"显示指标"(默认 API 用量):
///  1. 阈值:越过警告线/严重线,同一账期每一档只发一次。
///  2. 增量:比上次提醒时又增长了 N%(默认 2%,可设置)就发一次。
final class Notifier {
    static let shared = Notifier()

    private let levelKey = "notifiedLevel"
    private let cycleKey = "notifiedCycle"
    private let baselineKey = "stepBaseline"

    /// 通知只在以 .app 运行时可用
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: 增量决策(纯函数,便于自测)

    enum StepResult: Equatable {
        case setBaseline(Double)   // 记录新基准,不通知(首次、新账期、用量回落)
        case notify(from: Double)  // 增长够了:通知,并把基准更新为当前值
        case none                  // 增长不够,保持基准
    }

    static func decideStep(baseline: Double?, current: Double, step: Double) -> StepResult {
        guard let baseline else { return .setBaseline(current) }
        if current < baseline { return .setBaseline(current) }
        if current - baseline >= step { return .notify(from: baseline) }
        return .none
    }

    // MARK: 评估

    func evaluate(_ snap: UsageSnapshot) {
        let mode = Pref.metricMode
        guard let p = snap.percent(for: mode) else { return }
        let d = UserDefaults.standard

        // 新账期:重置阈值档位,并以当前值作为增量基准(不通知)
        let cycle = snap.cycleEnd?.timeIntervalSince1970 ?? 0
        if d.double(forKey: cycleKey) != cycle {
            d.set(cycle, forKey: cycleKey)
            d.set(UsageLevel.normal.rawValue, forKey: levelKey)
            d.set(p, forKey: baselineKey)
        }

        let thresholdSent = evaluateThreshold(p, snap: snap, mode: mode, defaults: d)
        if !thresholdSent {
            evaluateStep(p, snap: snap, mode: mode, defaults: d)
        }
    }

    /// 返回是否发出了阈值通知
    private func evaluateThreshold(_ p: Double, snap: UsageSnapshot, mode: MetricMode, defaults d: UserDefaults) -> Bool {
        let level = UsageLevel(percent: p)
        let stored = UsageLevel(rawValue: d.integer(forKey: levelKey)) ?? .normal

        if level < stored {
            d.set(level.rawValue, forKey: levelKey)   // 用量回落(或切换了指标)后重新允许提醒
            return false
        }
        guard level > stored else { return false }

        d.set(level.rawValue, forKey: levelKey)
        d.set(p, forKey: baselineKey)                 // 刚提醒过,增量从这里重新算
        guard Pref.notifications else { return false }

        let title = level == .critical ? "Cursor \(mode.label)即将耗尽" : "Cursor \(mode.label)提醒"
        send(id: "level-\(level.rawValue)", title: title, body: body(mode: mode, percent: p, resetIn: snap.resetCountdown))
        return true
    }

    private func evaluateStep(_ p: Double, snap: UsageSnapshot, mode: MetricMode, defaults d: UserDefaults) {
        let baseline = d.object(forKey: baselineKey) as? Double
        switch Self.decideStep(baseline: baseline, current: p, step: Pref.step) {
        case .setBaseline(let v):
            d.set(v, forKey: baselineKey)
        case .notify(let from):
            d.set(p, forKey: baselineKey)   // 无论是否开启通知都推进基准,避免开启后一次性补发
            guard Pref.notifications && Pref.stepNotify else { return }
            send(id: "step",
                 title: "Cursor \(mode.label) +\(String(format: "%.1f", p - from))%",
                 body: body(mode: mode, percent: p, resetIn: snap.resetCountdown)
                     + "(上次提醒时 \(Fmt.percent1(from)))")
        case .none:
            break
        }
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

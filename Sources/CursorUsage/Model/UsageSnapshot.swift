import Foundation

/// 一次拉取得到的用量快照(可缓存,不含任何凭据)。金额单位为美分。
struct UsageSnapshot: Codable, Equatable {
    var plan: String?
    /// 总用量百分比,与 Cursor 官方界面一致
    var percent: Double?
    /// Auto 模型 / 指定(API)模型各自的占用百分比
    var autoPercent: Double?
    var apiPercent: Double?
    /// 已消耗总额(含赠送额度)、套餐包含额度、其中赠送部分
    var usedCents: Double?
    var limitCents: Double?
    var bonusCents: Double?
    var onDemandUsedCents: Double?
    var onDemandLimitCents: Double?
    var onDemandEnabled: Bool?
    var cycleStart: Date?
    var cycleEnd: Date?
    var fetchedAt: Date

    /// 解析 DashboardService/GetCurrentPeriodUsage 的响应。一个有用字段都没有时返回 nil。
    init?(json: [String: Any], plan: String? = nil, now: Date = Date()) {
        let planUsage = J.dict(json["planUsage"])
        let spendLimit = J.dict(json["spendLimitUsage"])

        let used = J.firstNum(planUsage, ["totalSpend", "includedSpend"])
        let limit = J.firstNum(planUsage, ["limit"])
        let onDemandUsed = J.firstNum(spendLimit, ["individualUsed", "totalSpend"])
        let onDemandLimit = J.firstNum(spendLimit, ["individualLimit"])

        // 以接口给的 totalPercentUsed 为准。不能用 used/limit:totalSpend 含赠送额度,会超过 100%。
        // 只有接口没给时才回退到 used/limit。
        let percent: Double?
        if let reported = J.firstNum(planUsage, ["totalPercentUsed"]) {
            percent = reported
        } else if let used, let limit, limit > 0 {
            percent = used / limit * 100
        } else {
            percent = nil
        }

        if percent == nil && used == nil && onDemandUsed == nil { return nil }

        self.plan = plan
        self.percent = percent
        self.autoPercent = J.firstNum(planUsage, ["autoPercentUsed"])
        self.apiPercent = J.firstNum(planUsage, ["apiPercentUsed"])
        self.usedCents = used
        self.limitCents = limit
        self.bonusCents = J.firstNum(planUsage, ["bonusSpend"])
        self.onDemandUsedCents = onDemandUsed
        self.onDemandLimitCents = onDemandLimit
        self.onDemandEnabled = onDemandLimit != nil ? true : nil
        self.cycleStart = Self.parseDate(json["billingCycleStart"])
        self.cycleEnd = Self.parseDate(json["billingCycleEnd"])
        self.fetchedAt = now
    }

    /// 按指标取百分比;该分项缺失时回退到总用量。
    func percent(for mode: MetricMode) -> Double? {
        switch mode {
        case .api: return apiPercent ?? percent
        case .auto: return autoPercent ?? percent
        case .total, .amount: return percent
        }
    }

    var daysLeft: Int? {
        guard let end = cycleEnd else { return nil }
        return max(0, Int(ceil(end.timeIntervalSinceNow / 86_400)))
    }

    // MARK: 日期解析

    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    /// 支持 ISO8601(带/不带毫秒)和 Unix 时间戳(秒或毫秒,数字或字符串)
    static func parseDate(_ v: Any?) -> Date? {
        if let s = v as? String, s.contains("-") || s.contains(":") {
            return isoWithFraction.date(from: s) ?? isoPlain.date(from: s)
        }
        if let n = J.num(v) {
            return Date(timeIntervalSince1970: n > 1e11 ? n / 1000 : n)
        }
        return nil
    }
}

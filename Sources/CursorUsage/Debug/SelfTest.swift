import Foundation

/// `--selftest`:用假数据验证解析和计算逻辑,不读取任何凭据、不联网。
enum SelfTest {
    private static var failures = 0

    /// 返回进程退出码
    static func run() -> Int32 {
        print("SelfTest")
        Pref.register()

        apiKey()
        jwt()
        parsing()
        metrics()
        levels()
        steps()
        dates()

        print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
        return failures == 0 ? 0 : 1
    }

    private static func check(_ cond: Bool, _ name: String) {
        print(cond ? "  ok   \(name)" : "  FAIL \(name)")
        if !cond { failures += 1 }
    }

    private static func parse(_ s: String, plan: String? = nil) -> UsageSnapshot? {
        guard let o = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any] else { return nil }
        return UsageSnapshot(json: o, plan: plan)
    }

    /// 真实账号的响应形状:totalSpend 含赠送额度,used/limit 会超过 100%
    private static let realResponse = """
    {"billingCycleStart":"1791616767000","billingCycleEnd":"1794295167000",
     "planUsage":{"apiPercentUsed":90.874,"autoPercentUsed":10.873,"bonusSpend":38057,
                  "includedSpend":40000,"limit":40000,"totalPercentUsed":22.302,"totalSpend":78057},
     "spendLimitUsage":{"limitType":"user"},"enabled":true}
    """

    private static func apiKey() {
        check(ApiKeyStore.looksValid("crsr_" + String(repeating: "a", count: 40)), "合法 Key 格式")
        check(!ApiKeyStore.looksValid("sk-abc"), "非 crsr_ 前缀被拒绝")
        check(!ApiKeyStore.looksValid("crsr_ab cd" + String(repeating: "a", count: 20)), "含空格被拒绝")
    }

    private static func jwt() {
        let payload = #"{"sub":"x","exp":1900000000}"#
        let b64 = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        check(TokenProvider.jwtExpiry("h.\(b64).s") == Date(timeIntervalSince1970: 1_900_000_000), "JWT exp 解析")
        check(TokenProvider.jwtExpiry("garbage") == nil, "非法 JWT 返回 nil")
    }

    private static func parsing() {
        // 数字以字符串返回、毫秒时间戳字符串
        let stringy = """
        {"billingCycleStart":"1767225600000","billingCycleEnd":"1769904000000",
         "planUsage":{"totalSpend":"1200","limit":"2000","totalPercentUsed":60},
         "spendLimitUsage":{"individualUsed":"300","individualLimit":"5000"}}
        """
        if let s = parse(stringy, plan: "ultra") {
            check(s.percent == 60, "字符串数字: percent")
            check(s.usedCents == 1200 && s.limitCents == 2000, "字符串数字: used/limit")
            check(s.onDemandUsedCents == 300 && s.onDemandLimitCents == 5000, "字符串数字: on-demand")
            check(s.plan == "ultra", "套餐名由调用方传入")
            check(s.cycleEnd != nil, "毫秒时间戳字符串")
        } else { check(false, "字符串数字响应解析") }

        if let s = parse(realResponse, plan: "Ultra") {
            check(s.percent == 22.302, "真实形状: 取 totalPercentUsed 而不是 used/limit(195%)")
            check(s.apiPercent == 90.874 && s.autoPercent == 10.873, "真实形状: auto/api 分项")
            check(s.bonusCents == 38057 && s.usedCents == 78057, "真实形状: 赠送与已消耗")
        } else { check(false, "真实形状响应解析") }

        check(parse(#"{"planUsage":{"totalSpend":500,"limit":2000}}"#)?.percent == 25, "无 totalPercentUsed 时回退 used/limit")

        if let s = parse(#"{"planUsage":{"totalSpend":"x","totalPercentUsed":42.5}}"#) {
            check(s.percent == 42.5 && s.usedCents == nil, "类型错误的字段被忽略")
        } else { check(false, "容错解析") }
        check(parse(#"{"foo":1}"#) == nil, "无可用字段 -> nil")
    }

    private static func metrics() {
        guard let s = parse(realResponse) else { return check(false, "指标: 解析") }
        check(s.percent(for: .api) == 90.874, "指标 api")
        check(s.percent(for: .auto) == 10.873, "指标 auto")
        check(s.percent(for: .total) == 22.302 && s.percent(for: .amount) == 22.302, "指标 total/amount")
        check(parse(#"{"planUsage":{"totalPercentUsed":30}}"#)?.percent(for: .api) == 30, "api 缺失回退总用量")
    }

    private static func levels() {  // 默认警告线 80、严重线 90
        check(UsageLevel(percent: 10) == .normal, "10% -> 正常")
        check(UsageLevel(percent: 85) == .warning, "85% -> 警告")
        check(UsageLevel(percent: 95) == .critical, "95% -> 严重")
        check(UsageLevel(percent: nil) == .normal, "nil -> 正常")
        check(UsageLevel.warning < UsageLevel.critical, "档位可比较")
    }

    private static func steps() {  // 增量提醒决策
        check(Notifier.decideStep(baseline: nil, current: 50, step: 2) == .setBaseline(50), "首次只记基准,不通知")
        check(Notifier.decideStep(baseline: 50, current: 51.9, step: 2) == .none, "增长 1.9% 不提醒")
        check(Notifier.decideStep(baseline: 50, current: 52, step: 2) == .notify(from: 50), "增长 2% 提醒")
        check(Notifier.decideStep(baseline: 50, current: 57, step: 2) == .notify(from: 50), "一次增长多于步长也只提醒一次")
        check(Notifier.decideStep(baseline: 50, current: 10, step: 2) == .setBaseline(10), "用量回落(新账期)重置基准")
        check(Notifier.decideStep(baseline: 50, current: 52.4, step: 2.5) == .none, "步长 2.5% 时 2.4% 不提醒")
    }

    private static func dates() {
        check(UsageSnapshot.parseDate("2026-11-01T00:00:00Z") != nil, "无毫秒 ISO8601")
        check(UsageSnapshot.parseDate("2026-11-01T00:00:00.000Z") != nil, "带毫秒 ISO8601")
        check(UsageSnapshot.parseDate("1767225600000") != nil, "毫秒时间戳(字符串)")
        check(UsageSnapshot.parseDate(1767225600000 as NSNumber) != nil, "毫秒时间戳(数字)")
        check(UsageSnapshot.parseDate(1767225600 as NSNumber) != nil, "秒时间戳(数字)")
        check(UsageSnapshot.parseDate("not a date") == nil, "非法日期 -> nil")
    }
}

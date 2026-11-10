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
        grok()
        today()
        tokens()
        countdown()
        levels()
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

    private static func json(_ s: String) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any]
    }

    private static func grok() {
        let usage = json(realResponse)!

        // 有独立额度:重置时间可以是毫秒字符串
        let own = json(#"{"usagePercent":37.5,"nextResetTimestampUtc":"1794295167000","hasNonZeroIncludedLimit":true}"#)
        let s = UsageSnapshot(json: usage, grok: own)
        check(s?.grokPercent == 37.5, "Grok: 百分比")
        check(s?.grokResetAt == Date(timeIntervalSince1970: 1_794_295_167), "Grok: 重置时间(毫秒字符串)")
        check(s?.percent(for: .grok) == 37.5, "指标 grok")

        // Connect JSON 省略零值字段:有额度但没有 usagePercent 时按 0% 处理
        check(UsageSnapshot(json: usage, grok: json(#"{"hasNonZeroIncludedLimit":true}"#))?.grokPercent == 0, "Grok: 缺省 usagePercent 按 0%")

        // 没有独立额度的各种情形 -> 不显示,指标回退总用量
        let none: [(String, String)] = [
            ("企业共享额度", #"{"usagePercent":5,"usesPooledEnterpriseAllowance":true}"#),
            ("额度为 0", #"{"usagePercent":5,"includedLimitZero":true}"#),
            ("无非零额度", #"{"usagePercent":5,"hasNonZeroIncludedLimit":false}"#),
            ("合并套餐(与 Cursor 共用额度池)", #"{"usagePercent":5,"isUnified":true}"#),
        ]
        for (name, body) in none {
            check(UsageSnapshot(json: usage, grok: json(body))?.grokPercent == nil, "Grok 无独立额度: \(name)")
        }
        check(UsageSnapshot(json: usage, grok: nil)?.grokPercent == nil, "Grok 接口无返回 -> 无额度")
        check(UsageSnapshot(json: usage, grok: json("{}"))?.percent(for: .grok) == 22.302, "无 Grok 额度时指标回退总用量")
    }

    private static func today() {
        let usage = json(realResponse)!

        // 各模型 totalCents 求和(数字或字符串都接受)
        let agg = json(#"{"aggregations":[{"modelIntent":"composer-2.5","totalCents":2167.5},{"modelIntent":"grok-4.7","totalCents":"32.5"}]}"#)
        check(UsageSnapshot(json: usage, today: agg)?.todayTotal?.cents == 2200, "今日消耗: 各模型求和")

        // 没有数据的区间接口返回 {},应是 0 而不是"未取到"
        check(UsageSnapshot(json: usage, today: json("{}"))?.todayTotal?.cents == 0, "今日消耗: {} -> 0")
        check(UsageSnapshot(json: usage, today: nil)?.todayTotal == nil, "今日消耗: 接口失败 -> nil(不显示)")

        // 跨天的缓存不显示
        let fresh = UsageSnapshot(json: usage, today: agg, now: Date())
        let stale = UsageSnapshot(json: usage, today: agg, now: Date().addingTimeInterval(-2 * 86_400))
        check(fresh?.todayUsage != nil, "今日消耗: 当天有效")
        check(stale?.todayUsage == nil, "今日消耗: 跨天的缓存不显示")
    }

    private static func tokens() {
        let agg = json("""
        {"aggregations":[
          {"modelIntent":"composer-2.5","totalCents":1000,"inputTokens":"1000000","outputTokens":"200000","cacheReadTokens":"5000000","cacheWriteTokens":"100000"},
          {"modelIntent":"claude-opus","totalCents":2500,"inputTokens":"300000","outputTokens":"50000","cacheReadTokens":"2000000","cacheWriteTokens":"0"},
          {"modelIntent":"gpt-x","totalCents":80,"inputTokens":"1000","outputTokens":"500"}
        ]}
        """)
        let t = UsageSnapshot(json: json(realResponse)!, today: agg)?.todayTotal
        check(t?.cents == 3580, "今日合计: 金额")
        check(t?.input == 1_301_000 && t?.output == 250_500, "今日合计: 输入/输出 tokens")
        check(t?.cache == 7_100_000, "今日合计: 缓存读+写")
        check(t?.totalTokens == 8_651_500, "今日合计: 总 tokens(缺字段按 0)")

        check(Fmt.tokens(950) == "950", "tokens 格式: 个位")
        check(Fmt.tokens(12_300) == "12.3K", "tokens 格式: K")
        check(Fmt.tokens(4_900_000) == "4.9M", "tokens 格式: M")
        check(Fmt.tokens(1_200_000_000) == "1.20B", "tokens 格式: B")
    }

    private static func countdown() {
        check(Fmt.remaining(60) == "1分钟", "倒计时: 1 分钟")
        check(Fmt.remaining(30) == "不到1分钟", "倒计时: 不到 1 分钟")
        check(Fmt.remaining(0) == "已到重置时间" && Fmt.remaining(-5) == "已到重置时间", "倒计时: 已到点")
        check(Fmt.remaining(5 * 3600 + 12 * 60) == "5小时12分钟", "倒计时: 小时+分钟")
        check(Fmt.remaining(3 * 3600) == "3小时", "倒计时: 整小时")
        check(Fmt.remaining(2 * 86_400 + 3 * 3600 + 59) == "2天3小时", "倒计时: 天+小时")
        check(Fmt.remaining(2 * 86_400) == "2天", "倒计时: 整天")

        let past = UsageSnapshot(json: json(#"{"billingCycleEnd":"1000000000000","planUsage":{"totalPercentUsed":1}}"#)!)
        check(past?.isCycleOver == true, "账期已结束 -> 需要刷新")
        let future = UsageSnapshot(json: json(#"{"billingCycleEnd":"99999999999000","planUsage":{"totalPercentUsed":1}}"#)!)
        check(future?.isCycleOver == false, "账期未结束")
    }

    private static func levels() {  // 默认警告线 80、严重线 90
        check(UsageLevel(percent: 10) == .normal, "10% -> 正常")
        check(UsageLevel(percent: 85) == .warning, "85% -> 警告")
        check(UsageLevel(percent: 95) == .critical, "95% -> 严重")
        check(UsageLevel(percent: nil) == .normal, "nil -> 正常")
        check(UsageLevel.warning < UsageLevel.critical, "档位可比较")
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

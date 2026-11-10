import Foundation

/// 一段时间内的消耗:金额(美分)和各类 tokens。
struct TokenUsage: Codable, Equatable {
    var cents = 0.0
    var input = 0.0
    var output = 0.0
    var cacheRead = 0.0
    var cacheWrite = 0.0

    init() {}

    /// 来自 GetAggregatedUsageEvents 的一条按模型汇总
    init(row: [String: Any]) {
        cents = J.num(row["totalCents"]) ?? 0
        input = J.num(row["inputTokens"]) ?? 0
        output = J.num(row["outputTokens"]) ?? 0
        cacheRead = J.num(row["cacheReadTokens"]) ?? 0
        cacheWrite = J.num(row["cacheWriteTokens"]) ?? 0
    }

    var cache: Double { cacheRead + cacheWrite }
    var totalTokens: Double { input + output + cacheRead + cacheWrite }

    static func += (lhs: inout TokenUsage, rhs: TokenUsage) {
        lhs.cents += rhs.cents
        lhs.input += rhs.input
        lhs.output += rhs.output
        lhs.cacheRead += rhs.cacheRead
        lhs.cacheWrite += rhs.cacheWrite
    }
}

/// 今日用量及其按池子的拆分。
/// Cursor 把模型分成两个池子:Auto 池(`autoBucketModels` 里列出的模型)和 API 池(其余指定模型)。
struct TodayUsage: Codable, Equatable {
    var all: TokenUsage
    /// 拆分需要知道哪些模型属于 Auto 池;拿不到列表时为 nil,只显示总数
    var auto: TokenUsage?
    var api: TokenUsage?

    /// 汇总 GetAggregatedUsageEvents 的响应。没有数据的区间接口返回 `{}`,即今天 0。
    /// 接口失败(nil)返回 nil,界面就不显示这部分。
    init?(json: [String: Any]?, autoModels: Set<String>) {
        guard let json else { return nil }
        let rows = (json["aggregations"] as? [[String: Any]]) ?? []

        var all = TokenUsage(), auto = TokenUsage(), api = TokenUsage()
        for row in rows {
            let usage = TokenUsage(row: row)
            all += usage
            if autoModels.contains(J.str(row["modelIntent"]) ?? "") { auto += usage } else { api += usage }
        }
        self.all = all
        let canSplit = !autoModels.isEmpty
        self.auto = canSplit ? auto : nil
        self.api = canSplit ? api : nil
    }
}

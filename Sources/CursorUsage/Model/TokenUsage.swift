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

    /// 汇总 GetAggregatedUsageEvents 的响应(所有模型相加)。
    /// 没有数据的区间接口返回 `{}`,即今天 0;接口失败(nil)返回 nil,界面就不显示。
    init?(aggregate json: [String: Any]?) {
        guard let json else { return nil }
        self.init()
        for row in (json["aggregations"] as? [[String: Any]]) ?? [] {
            self += TokenUsage(row: row)
        }
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

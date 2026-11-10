import Foundation

/// `--dump`:打印接口的原始返回(格式化),方便核对字段。
/// 需要已配置 API Key(钥匙串或环境变量 CURSOR_API_KEY)。stderr 只输出各请求的状态码。
enum Dump {
    static func run() async {
        func err(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
        func pretty(_ obj: [String: Any]) -> String? {
            guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else { return nil }
            return String(data: data, encoding: .utf8)
        }

        do {
            let raw = try await CursorAPIClient().fetchRaw(log: err)

            err("\n===== GetCurrentPeriodUsage =====")
            if let text = pretty(raw.usage) { print(text) }

            err("\n===== GetSandUsageStatus (Grok Bot) =====")
            if let grok = raw.grok, let text = pretty(grok) { print(text) } else { err("(无返回:账号可能没有 Grok Bot 额度)") }

            err("\n===== GetAggregatedUsageEvents (今天 0 点至今) =====")
            if let today = raw.today, let text = pretty(today) { print(text) } else { err("(无返回)") }

            err("\n套餐名: \(raw.plan ?? "(未取到)")")
            let snap = UsageSnapshot(json: raw.usage, plan: raw.plan, grok: raw.grok, today: raw.today)
            err("解析为用量快照: \(snap != nil ? "成功" : "失败(字段不匹配)")")
            if let snap {
                err("Grok Bot 额度: \(snap.grokPercent.map { Fmt.percent1($0) } ?? "无独立额度")")
                if let t = snap.todayTotal {
                    err("今日消耗: \(Fmt.dollars(cents: t.cents)) · \(Fmt.tokenBreakdown(t))")
                } else {
                    err("今日消耗: (未取到)")
                }
            }
        } catch {
            err("错误: \(error.localizedDescription)")
        }
    }
}

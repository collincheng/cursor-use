import Foundation

/// `--dump`:打印用量接口的原始返回(格式化),方便核对字段。
/// 需要已配置 API Key(钥匙串或环境变量 CURSOR_API_KEY)。stderr 只输出各请求的状态码。
enum Dump {
    static func run() async {
        func err(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
        do {
            let (json, plan) = try await CursorAPIClient().fetchJSON(log: err)
            if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                print(text)
            }
            err("套餐名: \(plan ?? "(未取到)")")
            err("解析为用量快照: \(UsageSnapshot(json: json, plan: plan) != nil ? "成功" : "失败(字段不匹配)")")
        } catch {
            err("错误: \(error.localizedDescription)")
        }
    }
}

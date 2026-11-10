import Foundation

/// "显示指标":决定菜单栏数字、颜色、阈值和增量通知用哪个数。
enum MetricMode: String, CaseIterable, Identifiable {
    case api       // 指定(API)模型用量
    case auto      // Auto 模型用量
    case grok      // Grok Bot 每周额度(账号没有独立额度时回退到总用量)
    case total     // 总用量
    case amount    // 菜单栏显示已消耗金额;颜色和通知按总用量判断

    var id: String { rawValue }

    /// 用在通知和标签里的名称
    var label: String {
        switch self {
        case .api: return "API 用量"
        case .auto: return "Auto 用量"
        case .grok: return "Grok Bot 用量"
        case .total, .amount: return "总用量"
        }
    }

    /// 设置里下拉选项的名称
    var pickerTitle: String {
        self == .amount ? "已消耗金额" : label
    }
}

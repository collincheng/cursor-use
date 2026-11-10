import Foundation

/// 宽松的 JSON 取值。接口是非官方的,int64 常以字符串返回,所以数字要同时接受数字和字符串。
enum J {
    static func num(_ v: Any?) -> Double? {
        if let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }

    static func str(_ v: Any?) -> String? {
        if let s = v as? String, !s.isEmpty { return s }
        return nil
    }

    static func bool(_ v: Any?) -> Bool? {
        if let n = v as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue }
        return nil
    }

    static func dict(_ v: Any?) -> [String: Any]? { v as? [String: Any] }

    /// 依次尝试多个键,返回第一个能解析成数字的值
    static func firstNum(_ d: [String: Any]?, _ keys: [String]) -> Double? {
        guard let d else { return nil }
        for k in keys { if let n = num(d[k]) { return n } }
        return nil
    }
}

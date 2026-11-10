import Foundation
import Security

/// 用户自己创建的 Cursor User API Key(crsr_ 开头),存放在本应用自己的钥匙串条目里。
/// 不读取 Cursor 自身的任何登录数据。
enum ApiKeyStore {
    private static let service = "com.colin.cursor-usage"
    private static let account = "user-api-key"

    /// 进程内缓存:每次启动最多访问一次钥匙串,避免反复弹出授权框。
    private static let lock = NSLock()
    private static var cached: String?

    /// 环境变量优先(方便命令行调试),否则读钥匙串
    static func load() -> String? {
        if let env = ProcessInfo.processInfo.environment["CURSOR_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            return env
        }
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        cached = readFromKeychain()
        return cached
    }

    private static func readFromKeychain() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let s = String(data: data, encoding: .utf8), !s.isEmpty
        else { return nil }
        return s
    }

    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        let attrs: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: Data(key.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock,
        ]
        guard SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess else { return false }
        lock.lock(); cached = key; lock.unlock()
        return true
    }

    static func delete() {
        lock.lock(); cached = nil; lock.unlock()
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// 仅做格式检查,不联网
    static func looksValid(_ key: String) -> Bool {
        key.hasPrefix("crsr_") && key.count >= 20 && !key.contains(" ")
    }
}

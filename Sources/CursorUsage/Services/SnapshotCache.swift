import Foundation

/// 本地缓存,启动时先显示上次的值。只存用量数字,不含任何凭据。
enum SnapshotCache {
    private static let key = "cachedSnapshot"

    static func load() -> UsageSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
    }

    static func save(_ snapshot: UsageSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// 移除 Key 或 Key 失效时调用,避免下次启动又显示旧账号的用量
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

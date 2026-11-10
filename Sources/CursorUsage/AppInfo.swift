import Foundation

/// 应用自身的信息。版本号来自打包时写入 Info.plist 的值;用 `swift run` 直接运行时没有,显示为 "dev"。
enum AppInfo {
    static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }

    static var build: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    /// 如 "1.2.3 (build 45)";开发运行时只有 "dev"
    static var displayVersion: String {
        guard let build else { return version }
        return "\(version) (build \(build))"
    }
}

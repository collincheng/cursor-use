import Foundation
import ServiceManagement

/// 开机自启。仅在以 .app 形式运行时有效。
enum LaunchAtLogin {
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static var isEnabled: Bool {
        isAvailable && SMAppService.mainApp.status == .enabled
    }

    static func set(_ on: Bool) {
        guard isAvailable else { return }
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("LaunchAtLogin failed: \(error.localizedDescription)")
        }
    }
}

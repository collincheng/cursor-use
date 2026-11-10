import Foundation
import ServiceManagement

/// 开机自启。仅在以 .app 形式运行时有效。
enum LaunchAtLogin {
    static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    /// 开关应显示为开。包括已注册、但系统要求用户在「登录项」里允许的情况(requiresApproval),
    /// 否则注册成功后开关会立刻弹回。
    static var isEnabled: Bool {
        guard isAvailable else { return false }
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    /// 已注册,但还需要用户在「系统设置 → 登录项」中手动允许
    static var needsApproval: Bool {
        isAvailable && SMAppService.mainApp.status == .requiresApproval
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
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

import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore

    @AppStorage(Pref.refreshMinutes) private var refreshMinutes = 5
    @AppStorage(Pref.warnThreshold) private var warn = 80
    @AppStorage(Pref.critThreshold) private var crit = 90
    @AppStorage(Pref.menuBarMode) private var mode: MetricMode = .api
    @AppStorage(Pref.notificationsEnabled) private var notifications = true

    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.status != .needsKey {
                HStack {
                    Label("API Key 已配置", systemImage: "key.fill").foregroundStyle(.secondary)
                    Spacer()
                    Button("移除") { store.removeKey() }
                }
                ApiKeyEntryView(store: store)
                Divider()
            }

            Picker("刷新间隔", selection: $refreshMinutes) {
                ForEach([1, 2, 5, 15, 30], id: \.self) { Text("\($0) 分钟").tag($0) }
            }
            Picker("菜单栏/通知指标", selection: $mode) {
                ForEach(MetricMode.allCases) { Text($0.pickerTitle).tag($0) }
            }

            Toggle("超过警告线/严重线时发送通知", isOn: $notifications)
            // 两条线互相约束:警告线必须比严重线至少低 5 个点
            Stepper("警告线 \(warn)%", value: Binding(
                get: { warn },
                set: { warn = Pref.clampWarn($0, crit: crit) }
            ), in: 10...95, step: 5)
            Stepper("严重线 \(crit)%", value: Binding(
                get: { crit },
                set: { crit = Pref.clampCrit($0, warn: warn) }
            ), in: 10...100, step: 5)

            Toggle("开机自动启动", isOn: Binding(
                get: { launchAtLogin },
                set: { LaunchAtLogin.set($0); launchAtLogin = LaunchAtLogin.isEnabled }
            ))
            .disabled(!LaunchAtLogin.isAvailable)
            .help(LaunchAtLogin.isAvailable ? "" : "请以打包后的 .app 方式运行")
            if LaunchAtLogin.needsApproval {
                HStack {
                    Text("需在系统设置的登录项中允许").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("打开设置") { LaunchAtLogin.openSystemSettings() }
                        .buttonStyle(.link)
                }
            }
        }
        .font(.callout)
    }
}

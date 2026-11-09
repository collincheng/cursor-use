import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore

    @AppStorage(Pref.refreshMinutes) private var refreshMinutes = 5
    @AppStorage(Pref.warnThreshold) private var warn = 80
    @AppStorage(Pref.critThreshold) private var crit = 90
    @AppStorage(Pref.menuBarMode) private var mode: MetricMode = .api
    @AppStorage(Pref.notificationsEnabled) private var notifications = true
    @AppStorage(Pref.stepNotifyEnabled) private var stepNotify = true
    @AppStorage(Pref.stepPercent) private var stepPercent = 2.0

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

            Toggle("发送通知", isOn: $notifications)
            Toggle("每增长一定比例就提醒", isOn: $stepNotify)
                .disabled(!notifications)
            Stepper("提醒间隔 +\(String(format: "%.1f", stepPercent))%",
                    value: $stepPercent, in: 0.5...20, step: 0.5)
                .disabled(!notifications || !stepNotify)
            Stepper("警告线 \(warn)%", value: $warn, in: 10...99, step: 5)
            Stepper("严重线 \(crit)%", value: $crit, in: 10...100, step: 5)

            Toggle("开机自动启动", isOn: Binding(
                get: { launchAtLogin },
                set: { LaunchAtLogin.set($0); launchAtLogin = LaunchAtLogin.isEnabled }
            ))
            .disabled(!LaunchAtLogin.isAvailable)
            .help(LaunchAtLogin.isAvailable ? "" : "请以打包后的 .app 方式运行")
        }
        .font(.callout)
    }
}

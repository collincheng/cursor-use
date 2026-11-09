import AppKit
import SwiftUI

/// API Key 输入框。首次配置和设置里更换 Key 共用。
struct ApiKeyEntryView: View {
    @ObservedObject var store: UsageStore
    @State private var input = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SecureField("粘贴 crsr_… 开头的 API Key", text: $input)
                .textFieldStyle(.roundedBorder)
                .onSubmit(save)
            HStack {
                Button("保存", action: save).disabled(input.isEmpty)
                Button("去创建 Key") {
                    NSWorkspace.shared.open(URL(string: "https://cursor.com/dashboard")!)
                }
                Spacer()
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    private func save() {
        error = store.setKey(input)
        if error == nil { input = "" }
    }
}

/// 尚未配置 Key 时显示的引导
struct ApiKeySetupView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("需要一个 Cursor API Key 才能读取用量。").font(.callout)
            Text("在 cursor.com/dashboard 的 API Keys(Integrations)里创建,粘贴到下面。Key 只保存在本机钥匙串。")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ApiKeyEntryView(store: store)
        }
    }
}

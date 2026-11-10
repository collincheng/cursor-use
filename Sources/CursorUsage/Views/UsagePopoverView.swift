import AppKit
import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var store: UsageStore
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            if case .failed(let message) = store.status {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            if showSettings {
                SettingsView(store: store)
                Divider()
            }
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    @ViewBuilder
    private var content: some View {
        if store.status == .needsKey {
            ApiKeySetupView(store: store)
        } else if let snap = store.snapshot {
            UsageDetailView(snap: snap)
        } else {
            Text(store.status == .loading ? "加载中…" : "暂无数据").foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack {
            Text("Cursor 用量").font(.headline)
            Spacer()
            if let plan = store.snapshot?.plan, !plan.isEmpty {
                Text(plan.uppercased())
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                store.refresh()
            } label: {
                if store.status == .loading {
                    ProgressView().controlSize(.small)
                } else {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            Button {
                NSWorkspace.shared.open(URL(string: "https://cursor.com/dashboard")!)
            } label: {
                Label("网页", systemImage: "safari")
            }
            Spacer()
            Button { showSettings.toggle() } label: { Image(systemName: "gearshape") }
            Button("退出") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
    }
}

/// 弹窗里的用量详情。大数字固定为"总用量"(与 Cursor 官方界面一致);
/// "菜单栏/通知指标"设置只影响菜单栏和通知,API / Auto 在分项条里。
private struct UsageDetailView: View {
    let snap: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headline
            breakdown
            quota
            if snap.onDemandEnabled == true || (snap.onDemandUsedCents ?? 0) > 0 {
                InfoRow("按需用量", onDemandText)
            }
            if let end = snap.cycleEnd {
                ResetRow(title: "额度重置", date: end)
            }
            if snap.grokPercent != nil, let reset = snap.grokResetAt {
                ResetRow(title: "Grok Bot 重置", date: reset)
            }
            InfoRow("更新于", snap.fetchedAt.formatted(date: .omitted, time: .shortened))
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(Fmt.percent1(snap.percent))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("总用量").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if snap.usedCents != nil {
                    Text("已消耗 \(Fmt.dollars(cents: snap.usedCents))")
                        .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            ProgressBar(percent: snap.percent, height: 10)
        }
    }

    @ViewBuilder
    private var breakdown: some View {
        if snap.autoPercent != nil || snap.apiPercent != nil || snap.grokPercent != nil {
            VStack(alignment: .leading, spacing: 6) {
                if let p = snap.autoPercent { splitBar("Auto", p) }
                if let p = snap.apiPercent { splitBar("API", p) }
                if let p = snap.grokPercent { splitBar("Grok Bot", p, note: "独立每周额度,不计入总用量") }
            }
        }
    }

    @ViewBuilder
    private var quota: some View {
        if let today = snap.todayUsage {
            VStack(alignment: .leading, spacing: 2) {
                InfoRow("今日消耗", Fmt.dollars(cents: today.cents))
                if today.totalTokens > 0 {
                    InfoRow("今日 tokens", Fmt.tokens(today.totalTokens))
                    Text(Fmt.tokenBreakdown(today))
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        if let limit = snap.limitCents {
            InfoRow("套餐额度", Fmt.dollars(cents: limit))
        }
        if let bonus = snap.bonusCents, bonus > 0 {
            InfoRow("其中赠送已用", Fmt.dollars(cents: bonus))
        }
    }

    /// 标签列宽固定,三条进度条左右对齐;`note` 在条下方补一行小字说明。
    private func splitBar(_ title: String, _ percent: Double, note: String? = nil) -> some View {
        let labelWidth: CGFloat = 52
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(title).font(.caption).foregroundStyle(.secondary).frame(width: labelWidth, alignment: .leading)
                ProgressBar(percent: percent, height: 6)
                Text(Fmt.percent1(percent)).font(.caption).monospacedDigit().frame(width: 48, alignment: .trailing)
            }
            if let note {
                Text(note).font(.caption2).foregroundStyle(.secondary)
                    .padding(.leading, labelWidth + 8)
            }
        }
    }

    private var onDemandText: String {
        let used = Fmt.dollars(cents: snap.onDemandUsedCents ?? 0)
        guard let limit = snap.onDemandLimitCents else { return used }
        return "\(used) / \(Fmt.dollars(cents: limit))"
    }
}

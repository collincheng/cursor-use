import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let store: UsageStore
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore) {
        self.store = store
        super.init()

        if let button = item.button {
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: UsagePopoverView(store: store))

        store.$snapshot.combineLatest(store.$status)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in self?.render() }
            .store(in: &cancellables)

        // 设置变化(阈值、显示指标)时重绘
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.render() }
            .store(in: &cancellables)

        render()
    }

    private func render() {
        guard let button = item.button else { return }
        let content = menuBarContent()

        let image = MenuBarIcon.image(percent: content.percent)
        image.accessibilityDescription = "Cursor 用量"
        button.image = image

        var attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ]
        if let color = content.color { attrs[.foregroundColor] = color }
        button.attributedTitle = NSAttributedString(string: " " + content.text, attributes: attrs)
    }

    /// 菜单栏文字、颜色和图标进度。正常档位返回 nil 颜色,跟随系统菜单栏。
    private func menuBarContent() -> (text: String, color: NSColor?, percent: Double?) {
        var failed = false
        if case .failed = store.status { failed = true }

        guard let snap = store.snapshot else {
            if store.status == .needsKey { return ("未配置", nil, nil) }
            return (failed ? "⚠︎" : "…", nil, nil)
        }

        let mode = Pref.metricMode
        let metric = snap.percent(for: mode)
        var text = mode == .amount && snap.usedCents != nil
            ? Fmt.dollars(cents: snap.usedCents)
            : Fmt.percent(metric)
        if failed { text += "!" }

        let color: NSColor?
        switch UsageLevel(percent: metric) {
        case .normal: color = nil
        case .warning: color = .systemOrange
        case .critical: color = .systemRed
        }
        return (text, color, metric)
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            store.refresh()   // 打开时顺便刷新一次
        }
    }
}

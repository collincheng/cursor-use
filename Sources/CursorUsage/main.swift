import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: UsageStore?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditMenu()
        Pref.register()
        Notifier.shared.requestAuthorization()
        let store = UsageStore()
        self.store = store
        statusBar = StatusBarController(store: store)
        store.start()
    }

    /// .accessory 应用默认没有主菜单,⌘C/⌘V/⌘X/⌘A/⌘Z 等快捷键无人响应,
    /// 输入框里就无法复制粘贴。补一个标准的"编辑"菜单(不会显示在菜单栏,只用来派发快捷键)。
    private func installEditMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)

        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        NSApp.mainMenu = mainMenu
    }
}

let args = CommandLine.arguments
if args.contains("--version") {
    print("CursorUsage \(AppInfo.displayVersion)")
    exit(0)
}
if args.contains("--selftest") {
    exit(SelfTest.run())
}
if let i = args.firstIndex(of: "--icon-preview"), i + 1 < args.count {
    exit(IconPreview.run(outputPath: args[i + 1]))
}
if args.contains("--dump") {
    Task { await Dump.run(); exit(0) }
    dispatchMain()
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)   // 只在菜单栏显示,不出现在 Dock
    app.run()
}

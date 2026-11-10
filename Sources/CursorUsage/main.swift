import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: UsageStore?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Pref.register()
        Notifier.shared.requestAuthorization()
        let store = UsageStore()
        self.store = store
        statusBar = StatusBarController(store: store)
        store.start()
    }
}

let args = CommandLine.arguments
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

import AppKit
import Combine

@MainActor
final class UsageStore: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case ok
        case needsKey
        case failed(String)
    }

    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var status: Status = .idle

    private var lastFetch = Date.distantPast
    private var timer: Timer?
    private var inflight = false
    private let client = CursorAPIClient()

    init() {
        snapshot = SnapshotCache.load()   // 启动时先显示上次的值
    }

    func start() {
        refresh()
        // 每 30 秒检查一次是否到了刷新间隔,这样修改间隔设置即时生效。
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // 唤醒后网络可能还没恢复,稍等再刷新
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    /// 保存 API Key。格式不对返回错误文案,成功返回 nil。
    func setKey(_ raw: String) -> String? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ApiKeyStore.looksValid(key) else { return "Key 应以 crsr_ 开头,请检查是否复制完整" }
        guard ApiKeyStore.save(key) else { return "写入钥匙串失败" }
        resetAndRefresh()
        return nil
    }

    func removeKey() {
        ApiKeyStore.delete()
        snapshot = nil
        status = .needsKey
        Task { await TokenProvider.shared.reset() }
    }

    private func resetAndRefresh() {
        Task {
            await TokenProvider.shared.reset()
            inflight = false
            refresh()
        }
    }

    private func tick() {
        if Date().timeIntervalSince(lastFetch) >= Pref.refreshInterval { refresh() }
    }

    func refresh() {
        guard !inflight else { return }
        inflight = true
        status = .loading
        Task {
            do {
                let snap = try await client.fetchSnapshot()
                snapshot = snap
                status = .ok
                lastFetch = Date()
                SnapshotCache.save(snap)
                Notifier.shared.evaluate(snap)
            } catch {
                if case APIError.noKey = error {
                    status = .needsKey
                } else {
                    status = .failed(error.localizedDescription)
                }
                // 失败后 1 分钟再试,而不是等满一个间隔
                lastFetch = Date().addingTimeInterval(-Pref.refreshInterval + 60)
            }
            inflight = false
        }
    }
}

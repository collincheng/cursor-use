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
    /// 换 Key / 移除 Key 时递增。请求返回时代数已变,说明结果属于旧 Key,直接丢弃。
    private var generation = 0
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
        generation += 1   // 作废仍在飞的请求,它们返回时不再写回用量或状态
        inflight = false
        clearData()
        status = .needsKey
        Task { await TokenProvider.shared.reset() }
    }

    private func resetAndRefresh() {
        generation += 1   // 旧 Key 的请求可能还没回来:作废它,由新请求接管
        inflight = false
        Task {
            await TokenProvider.shared.reset()
            refresh()
        }
    }

    /// 清空内存和磁盘里的用量,避免没有 Key 时仍显示上一个账号的数字
    private func clearData() {
        snapshot = nil
        SnapshotCache.clear()
    }

    private func tick() {
        // 账期刚重置:当前数据属于上一个周期,立即刷新(但同一次重置只触发一次)
        if let end = snapshot?.cycleEnd, snapshot?.isCycleOver == true, lastFetch < end {
            refresh()
            return
        }
        if Date().timeIntervalSince(lastFetch) >= Pref.refreshInterval { refresh() }
    }

    func refresh() {
        guard !inflight else { return }
        inflight = true
        status = .loading
        let gen = generation
        Task {
            let result: Result<UsageSnapshot, Error>
            do { result = .success(try await client.fetchSnapshot()) }
            catch { result = .failure(error) }
            // 等待期间换过 Key:这次结果属于旧 Key,不写回。inflight 已由新请求接管,这里不能动它。
            guard gen == generation else { return }
            inflight = false
            apply(result)
        }
    }

    private func apply(_ result: Result<UsageSnapshot, Error>) {
        switch result {
        case .success(let snap):
            snapshot = snap
            status = .ok
            lastFetch = Date()
            SnapshotCache.save(snap)
            Notifier.shared.evaluate(snap)
        case .failure(let error):
            if case APIError.noKey = error {
                clearData()   // 没有 Key 就不能保留上一把 Key 的数据
                status = .needsKey
            } else {
                status = .failed(error.localizedDescription)
            }
            // 失败后 1 分钟再试,而不是等满一个间隔
            lastFetch = Date().addingTimeInterval(-Pref.refreshInterval + 60)
        }
    }
}

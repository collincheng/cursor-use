import Foundation

enum APIError: LocalizedError {
    case noKey
    case invalidKey
    case unauthorized
    case http(Int)
    case badResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .noKey: return "尚未配置 API Key"
        case .invalidKey: return "API Key 无效或已被撤销,请重新创建"
        case .unauthorized: return "鉴权失败(401),请重试或更换 API Key"
        case .http(let c): return "接口返回 HTTP \(c)"
        case .badResponse: return "接口返回内容无法解析(接口可能已变更)"
        case .network(let m): return "网络错误: \(m)"
        }
    }
}

/// 用 User API Key 兑换短期 accessToken,并在内存里缓存(不落盘)。
actor TokenProvider {
    static let shared = TokenProvider()

    private var token: String?
    private var expiry: Date?

    func reset() { token = nil; expiry = nil }

    func accessToken(forceRefresh: Bool = false, log: ((String) -> Void)? = nil) async throws -> String {
        if !forceRefresh, let token, let expiry, expiry.timeIntervalSinceNow > 300 { return token }
        guard let key = ApiKeyStore.load() else { throw APIError.noKey }

        var req = URLRequest(url: CursorAPIClient.exchangeURL, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw APIError.network(error.localizedDescription) }
        guard let http = resp as? HTTPURLResponse else { throw APIError.badResponse }
        log?("exchange_user_api_key: HTTP \(http.statusCode)")

        switch http.statusCode {
        case 200..<300: break
        case 400, 401, 403: throw APIError.invalidKey
        default: throw APIError.http(http.statusCode)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = obj["accessToken"] as? String, !t.isEmpty
        else { throw APIError.badResponse }

        token = t
        expiry = Self.jwtExpiry(t) ?? Date().addingTimeInterval(50 * 60)
        return t
    }

    static func jwtExpiry(_ jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let d = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let exp = J.num(obj["exp"])
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}

/// 非官方的 Connect RPC 接口。地址和鉴权集中在这里,接口变更时只改这一处。
struct CursorAPIClient {
    static let exchangeURL = URL(string: "https://api2.cursor.sh/auth/exchange_user_api_key")!
    static let base = "https://api2.cursor.sh/aiserver.v1.DashboardService/"

    private func call(_ method: String, token: String) async throws -> (Int, Data) {
        var req = URLRequest(url: URL(string: Self.base + method)!, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw APIError.badResponse }
            return (http.statusCode, data)
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    /// 返回用量 JSON 和(尽力获取的)套餐名。`log` 只会收到状态码,不含任何凭据。
    func fetchJSON(log: ((String) -> Void)? = nil) async throws -> (json: [String: Any], plan: String?) {
        var token = try await TokenProvider.shared.accessToken(log: log)
        var (status, data) = try await call("GetCurrentPeriodUsage", token: token)
        log?("GetCurrentPeriodUsage: HTTP \(status)")

        if status == 401 {   // token 可能刚好过期:强制重新兑换后重试一次
            token = try await TokenProvider.shared.accessToken(forceRefresh: true, log: log)
            (status, data) = try await call("GetCurrentPeriodUsage", token: token)
            log?("GetCurrentPeriodUsage(重试): HTTP \(status)")
        }
        switch status {
        case 200..<300: break
        case 401, 403: throw APIError.unauthorized
        default: throw APIError.http(status)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.badResponse
        }

        // 套餐名:失败不影响主流程
        var plan: String?
        if let (s, d) = try? await call("GetPlanInfo", token: token) {
            log?("GetPlanInfo: HTTP \(s)")
            if (200..<300).contains(s),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                plan = J.str(J.dict(o["planInfo"])?["planName"]) ?? J.str(o["planName"])
            }
        }
        return (json, plan)
    }

    func fetchSnapshot() async throws -> UsageSnapshot {
        let (json, plan) = try await fetchJSON()
        guard let snap = UsageSnapshot(json: json, plan: plan) else { throw APIError.badResponse }
        return snap
    }
}

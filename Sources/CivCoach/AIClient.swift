import Foundation
import Security

enum Keychain {
    static let service = "local.civ6.coach.api"
    static func load(account: String) throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data else { throw CoachError.message("无法读取钥匙串（\(status)）。请在设置中重新填写密钥。") }
        return String(decoding: data, as: UTF8.self)
    }
    static func save(_ key: String, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        if key.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw CoachError.message("无法删除旧密钥（\(status)）。") }
            return
        }
        let value = [kSecValueData as String: Data(key.utf8)]
        var status = SecItemUpdate(query as CFDictionary, value as CFDictionary)
        if status == errSecItemNotFound {
            var add = query; add.merge(value) { _, new in new }
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CoachError.message("密钥未能保存到钥匙串（\(status)）。") }
    }
}

final class NoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum APIProfileCredentials {
    static func apply(previous: Settings, next: Settings, keys: [UUID: String],
                      load: (String) throws -> String = Keychain.load,
                      save: (String, String) throws -> Void = { try Keychain.save($0, account: $1) }) throws {
        var desired: [String: String] = [:]
        for profile in next.apiProfiles {
            guard let key = keys[profile.id] else { throw CoachError.message("请重新读取或填写“\(profile.displayName)”的密钥。") }
            desired[profile.keyAccount] = key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for profile in previous.apiProfiles where desired[profile.keyAccount] == nil { desired[profile.keyAccount] = "" }
        var original: [String: String] = [:]
        for account in desired.keys { original[account] = try load(account) }
        var changed: [String] = []
        do {
            for account in desired.keys.sorted() where desired[account] != original[account] {
                changed.append(account)
                try save(desired[account]!, account)
            }
        } catch {
            var rollbackFailed = false
            for account in changed.reversed() {
                do { try save(original[account]!, account) } catch { rollbackFailed = true }
            }
            if rollbackFailed { throw CoachError.message("密钥保存失败，部分旧密钥未能恢复，请检查 API 配置。") }
            throw error
        }
    }
}

enum AIOutputBudget {
    case advice, chat, connectionTest
    var tokens: Int {
        switch self {
        case .advice: return 2048
        case .chat: return 4096
        case .connectionTest: return 1024
        }
    }
    var characters: Int {
        switch self {
        case .advice: return 600
        case .chat: return 6000
        case .connectionTest: return 128
        }
    }
}

enum AIStreamResult { case completed, limited }

struct StreamParser {
    var completed = false
    var limited = false
    mutating func consume(_ text: String) throws -> String {
        if text == "[DONE]" { completed = true; return "" }
        guard let data = text.data(using: .utf8), let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        if let error = obj["error"] as? [String: Any] { throw CoachError.message(error["message"] as? String ?? "API 返回错误。") }
        if let type = obj["type"] as? String {
            if type == "response.incomplete",
               let response = obj["response"] as? [String: Any],
               let details = response["incomplete_details"] as? [String: Any],
               details["reason"] as? String == "max_output_tokens" {
                completed = true; limited = true; return ""
            }
            if ["error", "response.failed", "response.incomplete"].contains(type) {
                throw CoachError.message(type == "response.incomplete" ? "回复未完成，可能达到模型输出限制。" : "AI 服务未能完成回复。请检查模型与账户状态。")
            }
            if type == "response.completed" { completed = true }
            if type == "response.output_text.delta" || type == "response.refusal.delta" { return obj["delta"] as? String ?? "" }
        }
        if let choices = obj["choices"] as? [[String: Any]], let choice = choices.first {
            if let reason = choice["finish_reason"] as? String {
                if reason == "length" { limited = true }
                if reason == "content_filter" { throw CoachError.message("服务商中止了本次回复。") }
                completed = true
            }
            if let delta = choice["delta"] as? [String: Any] { return (delta["content"] as? String) ?? (delta["refusal"] as? String) ?? "" }
        }
        return ""
    }
}

enum AIClient {
    static func makeRequest(settings: Settings, key: String, messages: [[String: String]], system: String, budget: AIOutputBudget = .chat) throws -> URLRequest {
        guard !settings.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CoachError.message("先在 AI 设置中填写模型名称。") }
        let url = try settings.validatedURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if !key.isEmpty { request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = ["model": settings.model.trimmingCharacters(in: .whitespacesAndNewlines), "stream": true]
        if settings.style == .chat {
            body["messages"] = [["role": "system", "content": system]] + messages
            // Reasoning-model families use the newer completion budget; other
            // compatible services commonly implement the legacy max_tokens field.
            let model = settings.model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().split(separator: "/").last.map(String.init) ?? ""
            let modern = ["gpt-5", "o1", "o3", "o4"].contains { model == $0 || model.hasPrefix($0 + "-") || model.hasPrefix($0 + ".") }
            body[modern ? "max_completion_tokens" : "max_tokens"] = budget.tokens
        } else {
            body["instructions"] = system; body["input"] = messages; body["store"] = false
            body["max_output_tokens"] = budget.tokens
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    @discardableResult static func stream(settings: Settings, key: String, messages: [[String: String]], system: String, budget: AIOutputBudget = .chat, onDelta: @escaping @Sendable (String) async -> Void) async throws -> AIStreamResult {
        let request = try makeRequest(settings: settings, key: key, messages: messages, system: system, budget: budget)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60; config.timeoutIntervalForResource = 180
        config.urlCredentialStorage = nil; config.httpCookieStorage = nil
        let session = URLSession(configuration: config, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var remaining = budget.characters
        func deliver(_ delta: String) async -> Bool {
            let bounded = String(delta.prefix(remaining))
            remaining -= bounded.count
            if !bounded.isEmpty { await onDelta(bounded) }
            return remaining == 0
        }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw CoachError.message("服务返回了无法识别的响应。") }
            guard (200..<300).contains(http.statusCode) else {
                let hint: String
                switch http.statusCode {
                case 401,403: hint = "检查 API Key 和模型访问权限。"
                case 404: hint = "检查服务地址、接口类型和模型名称。"
                case 429: hint = "请求过于频繁或余额不足，请稍后重试。"
                case 300..<400: hint = "服务地址发生重定向，请填写最终 API 地址。"
                default: hint = "服务暂时不可用，请稍后重试。"
                }
                throw CoachError.message("API HTTP \(http.statusCode)：\(hint)")
            }
            if !(http.value(forHTTPHeaderField: "Content-Type") ?? "").contains("text/event-stream") {
                var data = Data()
                for try await byte in bytes { try Task.checkCancellation(); data.append(byte); if data.count > 2_000_000 { throw CoachError.message("服务响应过大。") } }
                let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                let choices = obj["choices"] as? [[String: Any]]
                var limited = choices?.first?["finish_reason"] as? String == "length"
                if let reason = choices?.first?["finish_reason"] as? String, reason != "stop", reason != "length" {
                    throw CoachError.message("服务返回的回复不完整（\(reason)），请重试。")
                }
                if let status = obj["status"] as? String, status != "completed" {
                    let reason = (obj["incomplete_details"] as? [String: Any])?["reason"] as? String
                    if status == "incomplete", reason == "max_output_tokens" { limited = true }
                    else { throw CoachError.message("服务返回的回复不完整（\(status)），请重试。") }
                }
                if obj["error"] != nil { throw CoachError.message("服务返回错误，回复不完整。") }
                let message = choices?.first?["message"] as? [String: Any]
                var text = message?["content"] as? String ?? ""
                if text.isEmpty, let outputs = obj["output"] as? [[String: Any]] {
                    text = outputs.flatMap { $0["content"] as? [[String: Any]] ?? [] }.compactMap { $0["text"] as? String }.joined()
                }
                guard !text.isEmpty else { throw CoachError.message("服务没有返回文本，请检查接口协议或模型。") }
                let locallyLimited = await deliver(text)
                return limited || locallyLimited ? .limited : .completed
            }
            var parser = StreamParser(); var eventData = ""; var chars = 0; var hasText = false
            for try await line in bytes.lines {
                try Task.checkCancellation()
                chars += line.utf8.count
                // Transport metadata/reasoning is not answer text. Bound both
                // separately, and cancel as soon as the visible budget is spent.
                guard chars < 16_000_000 else { throw CoachError.message("模型持续返回过多数据，请换用更简短的模型或检查接口。") }
                guard line.utf8.count < 2_000_000 else { throw CoachError.message("API 单条数据异常过大，已停止接收。") }
                // AsyncBytes.lines omits empty lines on macOS. Flush complete JSON
                // values rather than relying on the SSE blank-line delimiter.
                if line.hasPrefix("data:") {
                    let fragment = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    eventData += (eventData.isEmpty ? "" : "\n") + fragment
                    guard eventData.utf8.count < 2_000_000 else { throw CoachError.message("API 单条数据异常过大，已停止接收。") }
                    if eventData == "[DONE]" || (try? JSONSerialization.jsonObject(with: Data(eventData.utf8))) != nil {
                        let delta = try parser.consume(eventData); eventData = ""
                        if !delta.isEmpty { hasText = true; if await deliver(delta) { return .limited } }
                        if parser.completed { break }
                    }
                }
            }
            if !eventData.isEmpty {
                let delta = try parser.consume(eventData)
                if !delta.isEmpty { hasText = true; if await deliver(delta) { return .limited } }
            }
            guard parser.completed else { throw CoachError.message("连接提前结束，回复可能不完整。请重试。") }
            guard hasText else { throw CoachError.message(parser.limited ? "模型已用完输出预算，但没有返回答案。请换用较少推理的模型。" : "模型没有返回文字。请确认模型支持文本对话。") }
            return parser.limited ? .limited : .completed
        } catch {
            if Task.isCancelled { throw CancellationError() }
            var message = error.localizedDescription
            if !key.isEmpty { message = message.replacingOccurrences(of: key, with: "[密钥已隐藏]") }
            throw CoachError.message(String(message.prefix(350)))
        }
    }
}

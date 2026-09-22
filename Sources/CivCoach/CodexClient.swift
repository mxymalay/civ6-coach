import Foundation
import Darwin

struct CodexEventParser {
    var completed = false
    mutating func consume(_ line: String) throws -> String {
        guard line.hasPrefix("{"), let event = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { return "" }
        switch event["type"] as? String {
        case "turn.completed": completed = true
        case "turn.failed", "error":
            let error = event["error"] as? [String: Any]
            throw CoachError.message("Codex：" + String((error?["message"] as? String ?? event["message"] as? String ?? "请求失败，请检查登录状态或用量。").prefix(300)))
        case "item.completed":
            if let item = event["item"] as? [String: Any], item["type"] as? String == "agent_message" { return item["text"] as? String ?? "" }
        default: break
        }
        return ""
    }
}

private final class ProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func check() throws { lock.lock(); let v = cancelled; lock.unlock(); if v { throw CancellationError() } }
}

enum CodexClient {
    static func executable(settings: Settings) throws -> URL {
        let custom = settings.codexPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = custom.isEmpty ? [home + "/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/Applications/Codex.app/Contents/Resources/codex"] : [NSString(string: custom).expandingTildeInPath]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { throw CoachError.message("未找到 Codex CLI。请先安装官方 CLI，或在设置中填写可执行文件路径。") }
        return URL(fileURLWithPath: path)
    }
    static func status(settings: Settings) async throws -> String {
        let result = try await run(settings: settings, arguments: ["login", "status"], input: nil, timeout: 20) { _ in }
        guard result.code == 0 else { return "尚未登录，请点击「登录 Codex」。" }
        if result.text.localizedCaseInsensitiveContains("ChatGPT") { return "已通过 ChatGPT 授权，可直接使用。" }
        return "CLI 已登录（当前可能使用 API Key；ChatGPT 授权请点击登录）。"
    }
    static func login(settings: Settings, onProgress: @escaping @Sendable (String) async -> Void) async throws {
        let result = try await run(settings: settings, arguments: ["login", "--device-auth"], input: nil, timeout: 900, onLine: onProgress)
        guard result.code == 0 else { throw CoachError.message("Codex 授权未完成，请重试。") }
    }
    static func stream(settings: Settings, messages: [[String: String]], system: String, onDelta: @escaping @Sendable (String) async -> Void) async throws {
        var args = ["exec", "--ignore-user-config", "--ephemeral", "--skip-git-repo-check", "--sandbox", "read-only", "--color", "never", "--json",
                    "-c", "features.shell_tool=false", "-c", "features.apps=false", "-c", "features.plugins=false", "-c", "features.multi_agent=false",
                    "-c", "web_search=\"disabled\"", "-c", "project_doc_max_bytes=0", "-c", "model_reasoning_effort=\"low\""]
        let model = settings.codexModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty { args += ["--model", model] }
        args.append("-")
        let prompt = system + "\n仅根据下面的数据回答，不使用工具、不读取本地文件。\n" + messages.map { "[\($0["role"] ?? "user")]\n\($0["content"] ?? "")" }.joined(separator: "\n\n")
        let parser = EventAccumulator(onDelta: onDelta)
        let result = try await run(settings: settings, arguments: args, input: prompt, timeout: 180) { line in try await parser.line(line) }
        guard result.code == 0 else { throw CoachError.message("Codex 请求失败（退出码 \(result.code)）。请检查授权、模型或用量。") }
        try await parser.finish()
    }
    private actor EventAccumulator {
        var parser = CodexEventParser()
        var hasText = false
        let onDelta: @Sendable (String) async -> Void
        init(onDelta: @escaping @Sendable (String) async -> Void) { self.onDelta = onDelta }
        func line(_ line: String) async throws {
            let text = try parser.consume(line)
            if !text.isEmpty { await onDelta((hasText ? "\n\n" : "") + text); hasText = true }
        }
        func finish() throws {
            guard parser.completed && hasText else { throw CoachError.message("Codex 没有完成回复，请重试。") }
        }
    }
    private static func run(settings: Settings, arguments: [String], input: String?, timeout: TimeInterval, onLine: @escaping @Sendable (String) async throws -> Void) async throws -> (code: Int32, text: String) {
        let executable = try executable(settings: settings)
        let flag = ProcessCancellation()
        let task = Task.detached(priority: .userInitiated) { () throws -> (Int32, String) in
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("civcoach-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let process = Process(); let pipe = Pipe()
            process.executableURL = executable; process.arguments = arguments; process.currentDirectoryURL = directory
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = executable.deletingLastPathComponent().path + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            // Reuse official CLI auth, not unrelated API key environment overrides.
            environment.removeValue(forKey: "OPENAI_API_KEY"); environment.removeValue(forKey: "CODEX_API_KEY")
            environment["NO_COLOR"] = "1"; environment["RUST_LOG"] = "error"
            process.environment = environment
            process.standardOutput = pipe; process.standardError = pipe
            var inputHandle: FileHandle?
            if let input {
                let file = directory.appendingPathComponent("prompt.txt")
                try Data(input.utf8).write(to: file, options: [.atomic])
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
                inputHandle = try FileHandle(forReadingFrom: file); process.standardInput = inputHandle
            } else { process.standardInput = FileHandle.nullDevice }
            defer { try? inputHandle?.close() }
            try flag.check(); try process.run()
            try? pipe.fileHandleForWriting.close()
            defer {
                if process.isRunning {
                    process.terminate()
                    usleep(100_000)
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                    process.waitUntilExit()
                }
                try? pipe.fileHandleForReading.close()
            }
            let fd = pipe.fileHandleForReading.fileDescriptor
            _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            let deadline = Date().addingTimeInterval(timeout)
            var pending = Data(); var transcript = ""; var total = 0; var eof = false
            while !eof {
                try flag.check()
                guard Date() < deadline else { throw CoachError.message("Codex 等待超时，可停止后重试。") }
                var p = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
                let result = poll(&p, 1, 100)
                if result < 0 && errno != EINTR { throw CoachError.message("无法读取 Codex 响应。") }
                if result > 0 || !process.isRunning {
                    var buffer = [UInt8](repeating: 0, count: 8192)
                    let n = read(fd, &buffer, buffer.count)
                    if n > 0 {
                        total += n; guard total < 4_000_000 else { throw CoachError.message("Codex 响应过大。") }
                        pending.append(contentsOf: buffer.prefix(n))
                        while let index = pending.firstIndex(of: 10) {
                            let line = String(decoding: pending[..<index], as: UTF8.self).trimmingCharacters(in: .newlines)
                            pending.removeSubrange(...index)
                            transcript += line + "\n"
                            try await onLine(line)
                        }
                    } else if n == 0 { eof = true }
                    else if errno != EAGAIN && errno != EINTR { throw CoachError.message("Codex 输出读取失败。") }
                }
            }
            if !pending.isEmpty { let line = String(decoding: pending, as: UTF8.self); transcript += line; try await onLine(line) }
            while process.isRunning { try flag.check(); if Date() > deadline { throw CoachError.message("Codex 等待超时。") }; usleep(20_000) }
            process.waitUntilExit()
            return (process.terminationStatus, transcript)
        }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { flag.cancel() })
    }
}

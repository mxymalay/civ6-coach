import Foundation
import Darwin

private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    func check() throws { lock.lock(); let v = value; lock.unlock(); if v { throw CancellationError() } }
}

actor GameClient {
    private var busy = false
    func snapshot(includeMap: Bool) async throws -> Snapshot {
        guard !busy else { throw CoachError.message("正在读取游戏，请稍候。") }
        busy = true
        defer { busy = false }
        let scriptURL = Bundle.main.url(forResource: "queries", withExtension: "lua") ?? Bundle.module.url(forResource: "queries", withExtension: "lua")!
        var lua = try String(contentsOf: scriptURL, encoding: .utf8)
        lua += "\ncollect_snapshot()"
        if includeMap {
            lua += "\ncollect_empire_map()"
        }
        let flag = CancellationFlag()
        let code = lua
        let task = Task.detached(priority: .userInitiated) { try Self.run(code, flag: flag) }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { flag.cancel() })
    }

    private static func run(_ script: String, flag: CancellationFlag) throws -> Snapshot {
        // Share a lock with the earlier MCP bridge; FireTuner accepts one client.
        let lockFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Civ6Coach")
        try FileManager.default.createDirectory(at: lockFolder, withIntermediateDirectories: true)
        let lockFD = open(lockFolder.appendingPathComponent("firetuner.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard lockFD >= 0 else { throw CoachError.message("无法创建游戏连接锁。") }
        defer { flock(lockFD, LOCK_UN); close(lockFD) }
        guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw CoachError.message("另一个陪练窗口正在读取游戏，稍后会自动重试。") }
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw CoachError.message("无法创建游戏连接。") }
        defer { close(fd); Thread.sleep(forTimeInterval: 0.5) }
        var noSig: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSig, socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        let deadline = Date().addingTimeInterval(18)
        func ready(_ event: Int16) throws {
            while true {
                try flag.check()
                guard Date() < deadline else { throw CoachError.message("游戏接口响应超时。请进入地图后重试；必要时重启游戏。") }
                var p = pollfd(fd: fd, events: event, revents: 0)
                let result = poll(&p, 1, 100)
                if result > 0 {
                    if p.revents & event != 0 { return }
                    if p.revents & Int16(POLLERR | POLLHUP | POLLNVAL) != 0 { throw CoachError.message("游戏连接中断。") }
                } else if result < 0 && errno != EINTR { throw CoachError.message("游戏连接不可用。") }
            }
        }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(4318).bigEndian
        inet_pton(AF_INET, "127.0.0.1", &address.sin_addr)
        let result = withUnsafePointer(to: &address) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        if result < 0 {
            guard errno == EINPROGRESS else { throw CoachError.message("未连接到文明 VI。请打开游戏、开启 Tuner，并载入单人地图。") }
            try ready(Int16(POLLOUT))
            var err: Int32 = 0; var size = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &size)
            guard err == 0 else { throw CoachError.message("未连接到文明 VI。请打开游戏、开启 Tuner，并载入单人地图。") }
        }
        func writeAll(_ data: Data) throws {
            var sent = 0
            while sent < data.count {
                try ready(Int16(POLLOUT))
                let n = data.withUnsafeBytes { Darwin.send(fd, $0.baseAddress!.advanced(by: sent), data.count - sent, 0) }
                if n > 0 { sent += n }
                else if errno != EAGAIN && errno != EINTR { throw CoachError.message("发送查询失败。") }
            }
        }
        func readExact(_ count: Int) throws -> Data {
            var data = Data(count: count); var offset = 0
            while offset < count {
                try ready(Int16(POLLIN))
                let remaining = count - offset
                let n = data.withUnsafeMutableBytes { recv(fd, $0.baseAddress!.advanced(by: offset), remaining, 0) }
                if n > 0 { offset += n }
                else if n == 0 { throw CoachError.message("游戏关闭了连接。请稍后重试。") }
                else if errno != EAGAIN && errno != EINTR { throw CoachError.message("读取游戏数据失败。") }
            }
            return data
        }
        func send(_ tag: UInt32, _ text: String) throws {
            var body = Data(text.utf8); body.append(0)
            var length = UInt32(body.count).littleEndian; var type = tag.littleEndian
            var frame = withUnsafeBytes(of: &length) { Data($0) }
            frame.append(withUnsafeBytes(of: &type) { Data($0) }); frame.append(body)
            try writeAll(frame)
        }
        func receive() throws -> String {
            let header = try readExact(8)
            let count = header.prefix(4).enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
            guard count > 0 && count <= 8_000_000 else { throw CoachError.message("游戏接口返回无效数据长度。") }
            var data = try readExact(Int(count))
            while data.last == 0 { data.removeLast() }
            return String(decoding: data, as: UTF8.self)
        }
        try send(4, "APP:"); try send(4, "LSQ:")
        var state: Int?
        while state == nil {
            let response = try receive()
            let tokens = response.replacingOccurrences(of: "\n", with: "\0").components(separatedBy: "\0")
            for (i,t) in tokens.enumerated() where t == "InGame" && i > 0 { state = Int(tokens[i-1]) }
            if response.contains("GameCore_Tuner") && state == nil { throw CoachError.message("已找到游戏，请载入存档进入地图。") }
        }
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let begin = "CCBEGIN_" + nonce; let end = "CCEND_" + nonce
        let code = "print('\(begin)'); local ok,err=pcall(function() \(script) end); if not ok then print('CCERROR:'..tostring(err)) end; print('\(end)')"
        try send(3, "CMD:\(state!):\(code)")
        var records: [Record] = []; var started = false; var bytes = 0
        while true {
            let payload = try receive()
            if payload.hasPrefix("ERR:") { throw CoachError.message("游戏查询出错：" + String(payload.prefix(200))) }
            guard payload.hasPrefix("O"), let separator = payload.range(of: ": ") else { continue }
            let line = String(payload[separator.upperBound...])
            if line == begin { started = true; continue }
            guard started else { continue }
            if line == end { break }
            if line.hasPrefix("CCERROR:") { throw CoachError.message("局势读取不完整：" + String(line.prefix(200))) }
            bytes += line.utf8.count
            guard bytes < 4_000_000 else { throw CoachError.message("本次局势过大，已停止读取。") }
            if line.hasPrefix("{") { records.append(try JSONDecoder().decode(Record.self, from: Data(line.utf8))) }
        }
        let metas = records.filter { $0.text("kind") == "meta" }
        guard let first = metas.first, first.int("turn") != nil else { throw CoachError.message("未收到有效回合信息。") }
        guard metas.allSatisfy({ $0.int("turn") == first.int("turn") && $0.int("player") == first.int("player") }) else { throw CoachError.message("读取时回合发生变化，请再刷新一次。") }
        let mapKinds = ["tile", "visible_unit", "own_unit_at_tile"]
        return Snapshot(records: records.filter { !mapKinds.contains($0.text("kind")) }, map: records.filter { mapKinds.contains($0.text("kind")) })
    }
}

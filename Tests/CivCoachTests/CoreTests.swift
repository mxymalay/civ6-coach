import XCTest
@testable import CivCoach

final class CoreTests: XCTestCase {
    func testEndpointNormalization() throws {
        var s = Settings()
        XCTAssertEqual(try s.validatedURL().absoluteString, "https://api.openai.com/v1/chat/completions")
        s.endpoint = "https://example.com/v1/chat/completions/"; s.style = .responses
        XCTAssertEqual(try s.validatedURL().absoluteString, "https://example.com/v1/responses")
        s.endpoint = "http://localhost:11434/v1"; s.style = .chat
        XCTAssertEqual(try s.validatedURL().scheme, "http")
        for invalid in ["http://example.com/v1", "https://name:password@example.com/v1", "https://example.com/v1?key=secret", "invalid"] {
            s.endpoint = invalid; XCTAssertThrowsError(try s.validatedURL())
        }
    }
    func testRequestShapesAndNoKeyInBody() throws {
        var s = Settings(); s.model = "test-model"
        let messages = [["role":"user", "content":"问题"]]
        let chat = try AIClient.makeRequest(settings: s, key: "test-secret", messages: messages, system: "老师")
        XCTAssertEqual(chat.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
        XCTAssertFalse(String(decoding: chat.httpBody!, as: UTF8.self).contains("test-secret"))
        let body = try JSONSerialization.jsonObject(with: chat.httpBody!) as! [String: Any]
        XCTAssertEqual((body["messages"] as! [[String:String]]).count, 2)
        s.style = .responses
        let response = try AIClient.makeRequest(settings: s, key: "", messages: messages, system: "老师")
        let rbody = try JSONSerialization.jsonObject(with: response.httpBody!) as! [String:Any]
        XCTAssertEqual(rbody["store"] as? Bool, false)
        XCTAssertEqual(rbody["instructions"] as? String, "老师")
        XCTAssertNil(response.value(forHTTPHeaderField: "Authorization"))
    }
    func testBothStreamFormats() throws {
        var parser = StreamParser()
        XCTAssertEqual(try parser.consume(#"{"choices":[{"delta":{"content":"你好"}}]}"#), "你好")
        XCTAssertEqual(try parser.consume(#"{"type":"response.output_text.delta","delta":"老师"}"#), "老师")
        _ = try parser.consume("[DONE]"); XCTAssertTrue(parser.completed)
        XCTAssertThrowsError(try parser.consume(#"{"type":"response.failed"}"#))
        XCTAssertThrowsError(try parser.consume(#"{"choices":[{"finish_reason":"length","delta":{}}]}"#))
    }
    func testUnknownFieldsDoNotBecomeZero() throws {
        let rows: [Record] = [["kind": .string("meta"), "turn": .number(4)], ["kind": .string("city"), "name": .string("首都")]]
        let snapshot = Snapshot(records: rows)
        XCTAssertFalse(quickTips(snapshot).contains { $0.title.contains("粮食") || $0.title.contains("住房") })
        XCTAssertEqual(snapshot.cities[0].display("housing"), "—")
    }
    func testProductionAndFoodWarnings() {
        let snap = Snapshot(records: [["kind": .string("city"), "name": .string("首都"), "production": .string("空闲"), "food_surplus": .number(0)]])
        XCTAssertEqual(quickTips(snap).count, 2)
        XCTAssertTrue(quickTips(snap).first!.urgent)
    }
    func testSettingsNeverEncodeSecrets() throws {
        let encoded = String(decoding: try JSONEncoder().encode(Settings()), as: UTF8.self)
        XCTAssertFalse(encoded.contains("apiKey")); XCTAssertFalse(encoded.contains("password"))
    }
    func testKeychainRoundTripAndDelete() throws {
        let account = "test-civcoach-" + UUID().uuidString
        defer { try? Keychain.save("", account: account) }
        try Keychain.save("test-value-1", account: account)
        XCTAssertEqual(try Keychain.load(account: account), "test-value-1")
        try Keychain.save("test-value-2", account: account)
        XCTAssertEqual(try Keychain.load(account: account), "test-value-2")
        try Keychain.save("", account: account)
        XCTAssertEqual(try Keychain.load(account: account), "")
    }
    func testLiveGameIfRequested() async throws {
        guard ProcessInfo.processInfo.environment["CIVCOACH_LIVE_TEST"] == "1" else { throw XCTSkip("Run with CIVCOACH_LIVE_TEST=1 and a loaded game") }
        let value = try await GameClient().snapshot(includeMap: true)
        XCTAssertGreaterThanOrEqual(value.turn, 0)
        XCTAssertFalse(value.cities.isEmpty)
        XCTAssertEqual(value.errors, 0)
        print("LIVE_GAME_OK turn=\(value.turn) cities=\(value.cities.count) map=\(value.map.count)")
    }
}

actor TextCollector {
    var text = ""
    func append(_ s: String) { text += s }
    func value() -> String { text }
}
final class APIIntegrationTests: XCTestCase {
    func testIncompleteJSONIsRejected() async {
        for style in APIStyle.allCases {
            do {
                try await AIClient.stream(settings: settings("json-incomplete", style), key: "", messages: [], system: "老师") { _ in }
                XCTFail("Incomplete JSON must not be treated as finished")
            } catch { XCTAssertTrue(error.localizedDescription.contains("完整")) }
        }
    }
    var process: Process!
    var port = 0
    override func setUpWithError() throws {
        let p = Process(); let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        p.arguments = [Bundle.module.url(forResource: "mock_api", withExtension: "py", subdirectory: "Fixtures")!.path]
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        try p.run(); process = p
        var data = Data()
        while let byte = try pipe.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
            if byte == Data([10]) { break }; data.append(byte)
        }
        port = Int(String(decoding: data, as: UTF8.self))!
    }
    override func tearDownWithError() throws { process.terminate(); process.waitUntilExit() }
    func settings(_ model: String = "mock", _ style: APIStyle = .chat) -> Settings {
        var s = Settings(); s.endpoint = "http://127.0.0.1:\(port)/v1"; s.model = model; s.style = style; return s
    }
    func testChatAndResponsesOverHTTP() async throws {
        for style in APIStyle.allCases {
            let collector = TextCollector()
            try await AIClient.stream(settings: settings("mock", style), key: "test-key", messages: [["role":"user", "content":"测试"]], system: "老师") { await collector.append($0) }
            let text = await collector.value()
            XCTAssertEqual(text, "先发展城市。")
        }
    }
    func testJSONFallback() async throws {
        let collector = TextCollector()
        try await AIClient.stream(settings: settings("json"), key: "", messages: [], system: "老师") { await collector.append($0) }
        let text = await collector.value(); XCTAssertEqual(text, "普通JSON回复")
    }
    func testHTTPErrorAndIncompleteStream() async {
        for model in ["unauthorized", "truncated", "redirect"] {
            do {
                try await AIClient.stream(settings: settings(model), key: "secret-not-to-log", messages: [], system: "老师") { _ in }
                XCTFail("Expected error for \(model)")
            } catch { XCTAssertFalse(error.localizedDescription.contains("secret-not-to-log")) }
        }
    }
    func testCancellation() async throws {
        let s = settings("slow")
        let task = Task { try await AIClient.stream(settings: s, key: "", messages: [], system: "老师") { _ in } }
        try await Task.sleep(nanoseconds: 150_000_000)
        task.cancel()
        do { try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
    }
}

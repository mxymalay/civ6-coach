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
        XCTAssertEqual(try parser.consume(#"{"choices":[{"finish_reason":"length","delta":{"content":"尾"}}]}"#), "尾")
        XCTAssertTrue(parser.limited)
    }
    func testRequestBudgetsForBothProtocolsAndReasoningModels() throws {
        for style in APIStyle.allCases {
            for model in ["mock", "gpt-5.4", "openai/o3"] {
                for budget in [AIOutputBudget.advice, .chat, .connectionTest] {
                    var settings = Settings(); settings.style = style; settings.model = model
                    let request = try AIClient.makeRequest(settings: settings, key: "", messages: [], system: "老师", budget: budget)
                    let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
                    let field = style == .responses ? "max_output_tokens" : (model == "mock" ? "max_tokens" : "max_completion_tokens")
                    XCTAssertEqual(body[field] as? Int, budget.tokens)
                    XCTAssertEqual(["max_tokens", "max_completion_tokens", "max_output_tokens"].filter { body[$0] != nil }.count, 1)
                }
            }
        }
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
    func testLongAnswerStopsBeforeFloodingTheUI() async throws {
        for style in APIStyle.allCases {
            for model in ["long", "json-long"] {
                for budget in [AIOutputBudget.advice, .chat, .connectionTest] {
                    let collector = TextCollector()
                    let result = try await AIClient.stream(settings: settings(model, style), key: "", messages: [], system: "老师", budget: budget) { await collector.append($0) }
                    let text = await collector.value()
                    XCTAssertEqual(text.count, budget.characters)
                    XCTAssertEqual(result, .limited)
                }
            }
        }
    }
    func testBudgetExhaustionKeepsPartialAnswerWithoutClaimingCompletion() async throws {
        for style in APIStyle.allCases {
            for model in ["budget", "json-budget"] {
                let collector = TextCollector()
                let result = try await AIClient.stream(settings: settings(model, style), key: "", messages: [], system: "老师") { await collector.append($0) }
                let text = await collector.value()
                XCTAssertEqual(result, .limited)
                XCTAssertEqual(text, model == "json-budget" ? "已有建议" : (style == .chat ? "先发展城市。尾" : "先发展城市。"))
            }
        }
    }
    func testBudgetWithoutAnyAnswerStillReportsFailure() async {
        for style in APIStyle.allCases {
            do {
                try await AIClient.stream(settings: settings("reasoning-budget", style), key: "", messages: [], system: "老师") { _ in }
                XCTFail("A reasoning-only response is not usable advice")
            } catch { XCTAssertTrue(error.localizedDescription.contains("没有返回答案")) }
        }
    }
    func testReasoningTransportOverheadDoesNotRejectShortAnswer() async throws {
        for style in APIStyle.allCases {
            let collector = TextCollector()
            try await AIClient.stream(settings: settings("metadata", style), key: "", messages: [], system: "老师") { await collector.append($0) }
            let text = await collector.value()
            XCTAssertEqual(text, "先发展城市。")
        }
    }
    func testTransportStillRejectsRunawayDataAndOversizedEvents() async {
        for model in ["metadata-flood", "oversized-event"] {
            do {
                try await AIClient.stream(settings: settings(model), key: "", messages: [], system: "老师") { _ in }
                XCTFail("Runaway transport must still be bounded")
            } catch {
                XCTAssertTrue(error.localizedDescription.contains(model == "metadata-flood" ? "过多数据" : "单条数据"))
            }
        }
    }
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
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { XCTAssertTrue(error is CancellationError) }
    }
}

final class LiveAPIRegressionTests: XCTestCase {
    func testConfiguredAPIWithSyntheticAdviceIfRequested() async throws {
        guard ProcessInfo.processInfo.environment["CIVCOACH_LIVE_API_TEST"] == "1" else {
            throw XCTSkip("Opt in to a small request to the configured API using synthetic game data")
        }
        let data = try XCTUnwrap(UserDefaults(suiteName: "local.civ6.coach.desktop")?.data(forKey: "coach.settings.v1"))
        let config = try JSONDecoder().decode(Settings.self, from: data)
        let key = try Keychain.load(account: config.keyAccount)
        let collector = TextCollector()
        let result = try await AIClient.stream(settings: config, key: key,
            messages: [["role": "user", "content": "测试场景：第1回合，一座人口1的首都，生产队列为空，一名战士可移动。最多三条行动，每条一句，总计不超过180字。"]],
            system: teachingPrompt + "\n快速建议：最多三条，每条一句，总计不超过180字，只写行动和简短理由。",
            budget: .advice) { await collector.append($0) }
        let text = await collector.value()
        XCTAssertFalse(text.isEmpty)
        XCTAssertLessThanOrEqual(text.count, AIOutputBudget.advice.characters)
        XCTAssertEqual(result, .completed, "The configured model should finish a short advice request within its budget")
        print("LIVE_API_ADVICE model=\(config.model) characters=\(text.count) result=\(result)")
    }
}

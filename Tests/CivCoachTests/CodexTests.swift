import XCTest
@testable import CivCoach

final class CodexTests: XCTestCase {
    // Catches losing existing API preferences when upgrading with a new provider field.
    func testDecodeOldSettings() throws {
        let data = Data(#"{"endpoint":"https://example.com/v1","model":"existing-model","style":"Chat Completions","pollSeconds":15,"alwaysOnTop":true,"rememberChat":false,"includeMap":false,"goal":"文化胜利"}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(settings.model, "existing-model")
        XCTAssertEqual(settings.provider, .api)
        XCTAssertEqual(settings.pollSeconds, 15)
    }
    // Catches silently discarding a user-selected Codex provider during persistence.
    func testCodexSelectionRoundTrip() throws {
        let data = Data(#"{"provider":"codex","model":"","codexModel":"","codexPath":"/opt/homebrew/bin/codex"}"#.utf8)
        let value = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(value.provider, .codex)
        let saved = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(saved.provider, .codex)
    }
    func testCodexEventsOnlyShowAssistantMessages() throws {
        var parser = CodexEventParser()
        XCTAssertEqual(try parser.consume(#"{"type":"item.completed","item":{"type":"reasoning","text":"private reasoning"}}"#), "")
        XCTAssertEqual(try parser.consume(#"{"type":"item.completed","item":{"type":"agent_message","text":"先选择生产项目。"}}"#), "先选择生产项目。")
        _ = try parser.consume(#"{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}"#)
        XCTAssertTrue(parser.completed)
        XCTAssertThrowsError(try parser.consume(#"{"type":"turn.failed","error":{"message":"quota exceeded"}}"#))
    }
    func testCodexProcessIntegrationIfRequested() async throws {
        guard ProcessInfo.processInfo.environment["CIVCOACH_CODEX_TEST"] == "1" else { throw XCTSkip("Opt-in real Codex account test") }
        var settings = Settings(); settings.provider = .codex
        let status = try await CodexClient.status(settings: settings)
        XCTAssertTrue(status.contains("ChatGPT"), status)
        let collector = TextCollector()
        try await CodexClient.stream(settings: settings, messages: [["role":"user","content":"只回复：连接成功"]], system: "只输出简短中文，不使用任何工具。") { await collector.append($0) }
        let text = await collector.value()
        XCTAssertTrue(text.contains("连接成功"), text)
    }
}

import XCTest
@testable import CivCoach

final class ChatHistoryTests: XCTestCase {
    func testArchivesSortedAndCurrentChatUntouched() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = ChatMessage(role: "user", text: "旧对话", date: Date(timeIntervalSince1970: 100))
        let new = ChatMessage(role: "user", text: "新对话", date: Date(timeIntervalSince1970: 200))
        try JSONEncoder().encode([old]).write(to: directory.appendingPathComponent("conversation-old.json"))
        try JSONEncoder().encode([new]).write(to: directory.appendingPathComponent("conversation-new.json"))
        let current = try JSONEncoder().encode([new])
        try current.write(to: directory.appendingPathComponent("conversation.json"))
        try Data("invalid".utf8).write(to: directory.appendingPathComponent("conversation-broken.json"))
        try JSONEncoder().encode([ChatMessage]()).write(to: directory.appendingPathComponent("conversation-empty.json"))
        let result = try ChatHistoryStore.load(from: directory)
        XCTAssertEqual(result.items.map(\.title), ["新对话", "旧对话"])
        XCTAssertEqual(result.unreadable, 1)
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("conversation.json")), current)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("conversation-broken.json").path))
    }
    func testMissingDirectoryIsEmpty() throws {
        let result = try ChatHistoryStore.load(from: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.unreadable, 0)
    }
}

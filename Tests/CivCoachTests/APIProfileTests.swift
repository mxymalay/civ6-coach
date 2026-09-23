import XCTest
@testable import CivCoach

final class APIProfileTests: XCTestCase {
    func testLegacyMigrationAndRoundTrip() throws {
        let data = Data(#"{"endpoint":"https://example.com/v1","model":"original","goal":"练习扩城"}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(settings.keyAccount, "https://example.com/v1")
        XCTAssertEqual(settings.model, "original")
        XCTAssertEqual(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)), settings)
    }

    func testIndependentProfilesAndRemoval() throws {
        var settings = Settings()
        let first = settings.selectedAPIID
        let account = settings.keyAccount
        settings.model = "first"
        let second = settings.addAPIProfile()
        XCTAssertNotEqual(settings.keyAccount, account)
        settings.model = "second"
        settings.selectAPIProfile(first)
        XCTAssertEqual(settings.model, "first")
        settings.removeAPIProfile(first)
        XCTAssertEqual(settings.selectedAPIID, second)
        XCTAssertEqual(settings.model, "second")
        settings.removeAPIProfile(second)
        XCTAssertEqual(settings.apiProfiles.count, 1)
        XCTAssertNotEqual(settings.selectedAPIID, second)
        XCTAssertTrue(settings.model.isEmpty)
    }

    func testCredentialsIsolationAndDeletion() throws {
        let previous = Settings()
        var next = previous
        let second = next.addAPIProfile()
        var store = [previous.keyAccount: "original"]
        try APIProfileCredentials.apply(previous: previous, next: next,
            keys: [previous.selectedAPIID: "original", second: "second-secret"],
            load: { store[$0] ?? "" }, save: { store[$1] = $0 })
        XCTAssertEqual(store[previous.keyAccount], "original")
        XCTAssertEqual(store[next.keyAccount], "second-secret")
        let both = next
        next.removeAPIProfile(previous.selectedAPIID)
        try APIProfileCredentials.apply(previous: both, next: next, keys: [second: "second-secret"],
            load: { store[$0] ?? "" }, save: { store[$1] = $0 })
        XCTAssertEqual(store[previous.keyAccount], "")
        XCTAssertEqual(store[next.keyAccount], "second-secret")
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(next), as: UTF8.self).contains("second-secret"))
    }

    func testWriteFailureRollsBackAllAccounts() throws {
        let previous = Settings()
        var next = previous
        let second = next.addAPIProfile()
        var store = [previous.keyAccount: "original"]
        var writes = 0
        XCTAssertThrowsError(try APIProfileCredentials.apply(previous: previous, next: next,
            keys: [previous.selectedAPIID: "changed", second: "new"],
            load: { store[$0] ?? "" }, save: { value, account in
                writes += 1
                store[account] = value
                if writes == 2 { throw CoachError.message("test failure") }
            }))
        XCTAssertEqual(store[previous.keyAccount], "original")
        XCTAssertEqual(store[next.keyAccount] ?? "", "")
    }

    func testMissingCredentialDoesNotWrite() {
        let settings = Settings()
        var writes = 0
        XCTAssertThrowsError(try APIProfileCredentials.apply(previous: settings, next: settings, keys: [:],
            load: { _ in "existing" }, save: { _, _ in writes += 1 }))
        XCTAssertEqual(writes, 0)
    }
}

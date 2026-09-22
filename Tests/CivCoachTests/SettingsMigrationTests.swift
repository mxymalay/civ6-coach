import XCTest
@testable import CivCoach

final class SettingsMigrationTests: XCTestCase {
    func testOldCodexPreferencesRetainAPIAndThemeButDropLoginFields() throws {
        let old = Data(#"{"provider":"codex","codexModel":"old","codexPath":"/old/cli","endpoint":"https://example.com/v1","model":"my-model","theme":"white"}"#.utf8)
        let settings = try JSONDecoder().decode(Settings.self, from: old)
        XCTAssertEqual(settings.model, "my-model")
        XCTAssertEqual(settings.theme, .white)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        XCTAssertNil(saved["provider"])
        XCTAssertNil(saved["codexPath"])
        XCTAssertNil(saved["codexModel"])
    }
}

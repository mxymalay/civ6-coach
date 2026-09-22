import XCTest
@testable import CivCoach

final class QuickPanelTests: XCTestCase {
    func testPinnedPanelDoesNotDismissOutside() throws {
        var value = PanelPreferences()
        XCTAssertTrue(value.dismissesOnOutsideClick)
        value.pinned = true
        XCTAssertFalse(value.dismissesOnOutsideClick)
        let restored = try JSONDecoder().decode(PanelPreferences.self, from: JSONEncoder().encode(value))
        XCTAssertFalse(restored.dismissesOnOutsideClick)
    }
    func testRestoredWindowSizeIsClampedAndValidResizePersists() throws {
        let value = try JSONDecoder().decode(PanelPreferences.self, from: Data(#"{"width":-1,"height":90000,"pinned":true}"#.utf8))
        XCTAssertEqual(value.width, 360)
        XCTAssertEqual(value.height, 1000)
        var resized = PanelPreferences()
        resized.resize(width: 620, height: 740)
        let restored = try JSONDecoder().decode(PanelPreferences.self, from: JSONEncoder().encode(resized))
        XCTAssertEqual(restored.width, 620)
        XCTAssertEqual(restored.height, 740)
    }
}

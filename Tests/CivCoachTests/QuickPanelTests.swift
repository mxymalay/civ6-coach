import XCTest
import AppKit
@testable import CivCoach

final class QuickPanelTests: XCTestCase {
    func testResizeGripAnchorsTopLeftAndClampsSize() {
        let start = NSRect(x: 100, y: 300, width: 380, height: 520)
        let result = PanelResizeGeometry.frame(start: start, delta: NSSize(width: 100, height: -80), minimum: NSSize(width: 300, height: 200), maximum: NSSize(width: 1000, height: 1000), visible: NSRect(x: 0, y: 0, width: 1440, height: 900))
        XCTAssertEqual(result.width, 480); XCTAssertEqual(result.height, 600)
        XCTAssertEqual(result.minX, 100); XCTAssertEqual(result.maxY, 820)
        let tiny = PanelResizeGeometry.frame(start: start, delta: NSSize(width: -1000, height: 1000), minimum: NSSize(width: 300, height: 200), maximum: NSSize(width: 1000, height: 1000), visible: nil)
        XCTAssertEqual(tiny.size, NSSize(width: 300, height: 200))
    }
    func testUnpinAtBottomKeepsControlsOnScreen() {
        let result = PanelPresentation.keepingOnScreen(NSRect(x: 1100, y: -200, width: 360, height: 420), visible: NSRect(x: 0, y: 24, width: 1440, height: 876))
        XCTAssertEqual(result.minY, 24)
        XCTAssertEqual(result.maxX, 1440)
        XCTAssertEqual(result.height, 420)
    }
    func testOverlayCanShrinkAndReturningToNormalRestoresUsableMinimum() {
        var value = PanelPreferences()
        value.pinned = true
        value.resize(width: 320, height: 240)
        XCTAssertEqual(value.width, 320)
        XCTAssertEqual(value.height, 240)
        XCTAssertTrue(value.presentation.transparent)
        XCTAssertFalse(value.presentation.hasShadow)
        value.pinned = false
        value.resize(width: value.width, height: value.height)
        XCTAssertEqual(value.width, 360)
        XCTAssertEqual(value.height, 420)
        XCTAssertFalse(value.presentation.transparent)
        XCTAssertTrue(value.presentation.hasShadow)
    }
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
        XCTAssertEqual(value.width, 300)
        XCTAssertEqual(value.height, 1000)
        var resized = PanelPreferences()
        resized.resize(width: 620, height: 740)
        let restored = try JSONDecoder().decode(PanelPreferences.self, from: JSONEncoder().encode(resized))
        XCTAssertEqual(restored.width, 620)
        XCTAssertEqual(restored.height, 740)
    }
}

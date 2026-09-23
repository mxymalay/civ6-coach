import XCTest
import AppKit
@testable import CivCoach

final class QuickPanelTests: XCTestCase {
    func testLegacyPanelGetsFirstRunGuideAndDefaultTypography() throws {
        let value = try JSONDecoder().decode(PanelPreferences.self, from: Data("{}".utf8))
        XCTAssertTrue(value.overlay.shouldShowGuide)
        XCTAssertEqual(value.overlay.fontSize, 14)
        XCTAssertEqual(value.overlay.font, .system)
    }
    func testOverlayStylesAndGuidePersist() throws {
        var value = PanelPreferences()
        value.overlay.fontSize = 22
        value.overlay.font = .serif
        value.overlay.color = .cream
        value.overlay.shadow = .strong
        value.overlay.guideSeen = true
        let restored = try JSONDecoder().decode(PanelPreferences.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored.overlay, value.overlay)
        XCTAssertFalse(restored.overlay.shouldShowGuide)
        value.overlay.guideSeen = false
        value.overlay.guideEnabled = false
        XCTAssertFalse(value.overlay.shouldShowGuide)
        value.overlay.fontSize = 900
        let clamped = try JSONDecoder().decode(PanelPreferences.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(clamped.overlay.fontSize, 26)
    }
    func testHeaderDragDoesNotStealButtonsTextOrResizeEdges() {
        let bounds = NSRect(x: 0, y: 0, width: 380, height: 400)
        for transparent in [false, true] {
            XCTAssertTrue(PanelInteraction.isMoveArea(NSPoint(x: 50, y: 380), bounds: bounds, transparent: transparent))
            XCTAssertFalse(PanelInteraction.isMoveArea(NSPoint(x: 375, y: 380), bounds: bounds, transparent: transparent))
            XCTAssertFalse(PanelInteraction.isMoveArea(NSPoint(x: 50, y: 398), bounds: bounds, transparent: transparent))
            XCTAssertFalse(PanelInteraction.isMoveArea(NSPoint(x: 50, y: 200), bounds: bounds, transparent: transparent))
            XCTAssertFalse(PanelInteraction.isMoveArea(NSPoint(x: 340, y: 380), bounds: bounds, transparent: transparent))
        }
        XCTAssertFalse(PanelInteraction.isMoveArea(NSPoint(x: 290, y: 380), bounds: bounds, transparent: false))
        XCTAssertTrue(PanelInteraction.isMoveArea(NSPoint(x: 290, y: 380), bounds: bounds, transparent: true))
    }
    func testBothModesKeepIndependentSizesAndPinAcrossRestart() throws {
        var value = PanelPreferences()
        value.pinned = true
        value.resize(width: 430, height: 370)
        value.transparent = true
        value.resize(width: 270, height: 150)
        var restored = try JSONDecoder().decode(PanelPreferences.self, from: JSONEncoder().encode(value))
        XCTAssertTrue(restored.transparent)
        XCTAssertFalse(restored.dismissesOnOutsideClick)
        XCTAssertEqual(restored.width, 270)
        XCTAssertEqual(restored.height, 150)
        restored.transparent = false
        XCTAssertTrue(restored.pinned)
        XCTAssertFalse(restored.dismissesOnOutsideClick)
        XCTAssertEqual(restored.width, 430)
        XCTAssertEqual(restored.height, 370)
    }
    func testBorderHitZonesLeaveContentInteractive() {
        let bounds = NSRect(x: 0, y: 0, width: 320, height: 220)
        XCTAssertEqual(PanelResizeGeometry.edges(at: NSPoint(x: 5, y: 100), in: bounds), [.left])
        XCTAssertEqual(PanelResizeGeometry.edges(at: NSPoint(x: 310, y: 210), in: bounds), [.right, .top])
        XCTAssertTrue(PanelResizeGeometry.edges(at: NSPoint(x: 160, y: 110), in: bounds).isEmpty)
    }
    func testTopLeftResizeKeepsOppositeCorner() {
        let result = PanelResizeGeometry.frame(start: NSRect(x: 100, y: 100, width: 320, height: 220),
            delta: NSSize(width: -50, height: 40), minimum: NSSize(width: 240, height: 120),
            maximum: NSSize(width: 1000, height: 1000), visible: nil, edges: [.left, .top])
        XCTAssertEqual(result, NSRect(x: 50, y: 100, width: 370, height: 260))
    }
    func testOpaquePinDoesNotEnterTransparentMode() {
        var value = PanelPreferences()
        value.pinned = true
        XCTAssertFalse(value.presentation.transparent)
        XCTAssertFalse(value.dismissesOnOutsideClick)
    }
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
        value.resize(width: 410, height: 390)
        value.transparent = true
        XCTAssertFalse(value.dismissesOnOutsideClick)
        value.resize(width: 320, height: 240)
        XCTAssertEqual(value.width, 320)
        XCTAssertEqual(value.height, 240)
        XCTAssertTrue(value.presentation.transparent)
        XCTAssertFalse(value.presentation.hasShadow)
        value.transparent = false
        XCTAssertTrue(value.dismissesOnOutsideClick)
        XCTAssertEqual(value.width, 410)
        XCTAssertEqual(value.height, 390)
        value.transparent = true
        XCTAssertEqual(value.width, 320)
        XCTAssertEqual(value.height, 240)
        value.transparent = false
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
        XCTAssertEqual(value.width, 240)
        XCTAssertEqual(value.height, 1000)
        var resized = PanelPreferences()
        resized.resize(width: 620, height: 740)
        let restored = try JSONDecoder().decode(PanelPreferences.self, from: JSONEncoder().encode(resized))
        XCTAssertEqual(restored.width, 620)
        XCTAssertEqual(restored.height, 740)
    }
}

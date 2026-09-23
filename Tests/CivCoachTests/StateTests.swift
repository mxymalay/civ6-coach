import XCTest
@testable import CivCoach

final class StateTests: XCTestCase {
    @MainActor func testAppearancePreviewDoesNotChangeSavedSettingsAndCanBeDiscarded() {
        let state = AppState()
        state.setEnabled(false)
        let original = state.settings
        state.appearancePreview = (.violet, .light)
        XCTAssertEqual(state.displayedTheme, .violet)
        XCTAssertEqual(state.displayedAppearance, .light)
        XCTAssertEqual(state.settings, original)
        state.appearancePreview = nil
        XCTAssertEqual(state.displayedTheme, original.theme)
        XCTAssertEqual(state.displayedAppearance, original.appearance)
        state.appearancePreview = (.navy, .dark)
        state.settings.theme = .navy
        state.settings.appearance = .dark
        state.appearancePreview = nil
        XCTAssertEqual(state.displayedTheme, .navy)
        XCTAssertEqual(state.displayedAppearance, .dark)
    }
    @MainActor func testCoachingStartsWhenAppStateIsCreated() {
        let state = AppState()
        XCTAssertTrue(state.enabled, "Opening the app should start the local game reader without a switch")
        state.setEnabled(false)
    }
    func testFoundingOrRenamingCityDoesNotChangePlayerIdentity() {
        let meta: Record = ["kind": .string("meta"), "civilization": .string("俄罗斯"), "player": .number(0)]
        let before = Snapshot(records: [meta])
        let after = Snapshot(records: [meta, ["kind": .string("city"), "name": .string("新城")]])
        XCTAssertEqual(before.identity, after.identity)
    }
    @MainActor func testPauseDoesNotPrematurelyReleaseTestOwnership() {
        let state = AppState()
        state.testing = true
        state.setEnabled(false)
        XCTAssertTrue(state.testing, "Only the cancelled task's cleanup may release its ownership")
    }
}

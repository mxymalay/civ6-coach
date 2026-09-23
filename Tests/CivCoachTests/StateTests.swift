import XCTest
@testable import CivCoach

final class StateTests: XCTestCase {
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

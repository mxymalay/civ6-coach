import XCTest
@testable import CivCoach

final class ThemeTests: XCTestCase {
    func testOldPreferencesKeepGreenTheme() throws {
        let value = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
        XCTAssertEqual(value.theme, .forest)
    }
    func testAllThemesPersistAndWhiteUsesLightAppearance() throws {
        XCTAssertEqual(AppTheme.allCases.count, 5)
        for theme in AppTheme.allCases {
            var value = Settings(); value.theme = theme
            let restored = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(value))
            XCTAssertEqual(restored.theme, theme)
            XCTAssertEqual(theme.isLight, theme == .white)
        }
    }
}

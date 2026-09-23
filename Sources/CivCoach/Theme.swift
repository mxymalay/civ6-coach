import SwiftUI

enum AppTheme: String, Codable, CaseIterable {
    case forest, navy, violet, graphite, white
    var title: String {
        switch self {
        case .forest: return "森林绿"
        case .navy: return "海军蓝"
        case .violet: return "暮光紫"
        case .graphite: return "石墨黑"
        case .white: return "银灰"
        }
    }
    var isLight: Bool { self == .white }
    var colorScheme: ColorScheme { isLight ? .light : .dark }
    var palette: ThemePalette { palette(for: colorScheme) }
    func palette(for scheme: ColorScheme) -> ThemePalette {
        let light = scheme == .light
        switch self {
        case .forest:
            return ThemePalette(background: light ? 0xF7FAF8 : 0x0E1516, sidebar: light ? 0xEAF1ED : 0x131D1E, card: light ? 0xFFFFFF : 0x182425, accent: light ? 0x287654 : 0x99D6B8, secondary: light ? 0x52665B : 0xA0B2AF, light: light)
        case .navy:
            return ThemePalette(background: light ? 0xF6F8FC : 0x101725, sidebar: light ? 0xE9EEF7 : 0x172238, card: light ? 0xFFFFFF : 0x1E2C43, accent: light ? 0x356CAD : 0x96C7FF, secondary: light ? 0x56677C : 0xAABACE, light: light)
        case .violet:
            return ThemePalette(background: light ? 0xFAF7FC : 0x1B1424, sidebar: light ? 0xF0EAF6 : 0x251D31, card: light ? 0xFFFFFF : 0x30243F, accent: light ? 0x8255A4 : 0xD5B2F2, secondary: light ? 0x6A5B75 : 0xBEAEC9, light: light)
        case .graphite:
            return ThemePalette(background: light ? 0xF7F7F8 : 0x17181B, sidebar: light ? 0xECEDEF : 0x202226, card: light ? 0xFFFFFF : 0x2A2C31, accent: light ? 0x515A68 : 0xD2D8E3, secondary: light ? 0x5D626B : 0xB2B5BE, light: light)
        case .white:
            return ThemePalette(background: light ? 0xFFFFFF : 0x17191D, sidebar: light ? 0xF2F4F7 : 0x22252B, card: light ? 0xFAFBFC : 0x2C3037, accent: light ? 0x596472 : 0xD4DAE2, secondary: light ? 0x596472 : 0xB6BCC6, light: light)
        }
    }
}
enum AppAppearance: String, Codable, CaseIterable {
    case system, light, dark
    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    func resolve(system: ColorScheme) -> ColorScheme {
        switch self {
        case .system: return system
        case .light: return .light
        case .dark: return .dark
        }
    }
}
struct AppThemeStyle {
    var accent: AppTheme
    var appearance: AppAppearance
    var systemColorScheme: ColorScheme
    var colorScheme: ColorScheme { appearance.resolve(system: systemColorScheme) }
    var palette: ThemePalette { accent.palette(for: colorScheme) }
}
struct ThemePalette {
    let background: Color
    let sidebar: Color
    let card: Color
    let mint: Color
    let secondary: Color
    let primary: Color
    let gold: Color
    let line: Color
    let buttonText: Color
    init(background: UInt32, sidebar: UInt32, card: UInt32, accent: UInt32, secondary: UInt32, light: Bool = false) {
        func color(_ hex: UInt32) -> Color { Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
        self.background = color(background); self.sidebar = color(sidebar); self.card = color(card)
        mint = color(accent); self.secondary = color(secondary)
        primary = color(light ? 0x202A35 : 0xEDF1F0)
        gold = color(light ? 0x886020 : 0xD9BA7D)
        line = (light ? Color.black : Color.white).opacity(light ? 0.10 : 0.07)
        buttonText = light ? .white : color(background)
    }
}
private struct CoachThemeKey: EnvironmentKey {
    static let defaultValue = AppThemeStyle(accent: .forest, appearance: .system, systemColorScheme: .light)
}
extension EnvironmentValues {
    var coachTheme: AppThemeStyle {
        get { self[CoachThemeKey.self] }
        set { self[CoachThemeKey.self] = newValue }
    }
}

import SwiftUI

enum AppTheme: String, Codable, CaseIterable {
    case forest, navy, violet, graphite, white
    var title: String {
        switch self {
        case .forest: return "森林绿"
        case .navy: return "海军蓝"
        case .violet: return "暮光紫"
        case .graphite: return "石墨黑"
        case .white: return "纯白"
        }
    }
    var isLight: Bool { self == .white }
    var colorScheme: ColorScheme { isLight ? .light : .dark }
    var palette: ThemePalette {
        switch self {
        case .forest: return ThemePalette(background: 0x0E1516, sidebar: 0x131D1E, card: 0x182425, accent: 0x99D6B8, secondary: 0xA0B2AF)
        case .navy: return ThemePalette(background: 0x101725, sidebar: 0x172238, card: 0x1E2C43, accent: 0x96C7FF, secondary: 0xAABACE)
        case .violet: return ThemePalette(background: 0x1B1424, sidebar: 0x251D31, card: 0x30243F, accent: 0xD5B2F2, secondary: 0xBEAEC9)
        case .graphite: return ThemePalette(background: 0x17181B, sidebar: 0x202226, card: 0x2A2C31, accent: 0xD2D8E3, secondary: 0xB2B5BE)
        case .white: return ThemePalette(background: 0xFFFFFF, sidebar: 0xF2F4F7, card: 0xF7F8FA, accent: 0x246B50, secondary: 0x596472, light: true)
        }
    }
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
private struct CoachThemeKey: EnvironmentKey { static let defaultValue = AppTheme.forest }
extension EnvironmentValues {
    var coachTheme: AppTheme {
        get { self[CoachThemeKey.self] }
        set { self[CoachThemeKey.self] = newValue }
    }
}

import SwiftUI

struct OverlayOptions: Codable, Equatable {
    var guideEnabled = true
    var guideSeen = false
    var fontSize = 14
    var font = OverlayFont.system
    var color = OverlayColor.white
    var shadow = OverlayShadow.normal
    var shouldShowGuide: Bool { guideEnabled && !guideSeen }
}

enum OverlayFont: String, Codable, CaseIterable {
    case system = "系统", rounded = "圆体", serif = "衬线", monospaced = "等宽"
    var design: Font.Design {
        switch self {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
}
enum OverlayColor: String, Codable, CaseIterable {
    case white = "白色", cream = "米黄", mint = "薄荷绿", blue = "浅蓝", black = "深灰"
    var value: Color {
        switch self {
        case .white: return .white
        case .cream: return Color(red: 1, green: 0.9, blue: 0.65)
        case .mint: return Color(red: 0.65, green: 1, blue: 0.8)
        case .blue: return Color(red: 0.65, green: 0.85, blue: 1)
        case .black: return Color(white: 0.15)
        }
    }
}
enum OverlayShadow: String, Codable, CaseIterable {
    case none = "无", soft = "轻", normal = "中", strong = "强"
    var opacity: Double {
        switch self { case .none: return 0; case .soft: return 0.35; case .normal: return 0.65; case .strong: return 0.9 }
    }
    var radius: CGFloat {
        switch self { case .none: return 0; case .soft: return 1; case .normal: return 2; case .strong: return 4 }
    }
}

struct OverlayCornerMarks: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for x in [rect.minX + 4, rect.maxX - 4] {
            for y in [rect.minY + 4, rect.maxY - 4] {
                let dx: CGFloat = x < rect.midX ? 14 : -14
                let dy: CGFloat = y < rect.midY ? 14 : -14
                p.move(to: CGPoint(x: x + dx, y: y))
                p.addLine(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x, y: y + dy))
            }
        }
        return p
    }
}

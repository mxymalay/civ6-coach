import SwiftUI
import AppKit

/// A game HUD, not a translucent copy of the normal card.
struct GameOverlayView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 2) {
                Color.white.opacity(0.001).frame(maxWidth: .infinity).frame(height: 24)
                    .help("拖动顶部移动叠加层；拖动边框调整大小")
                Button { quickPanel.performOverlayAction() } label: {
                    Image(systemName: state.generating ? "stop.fill" : "sparkles")
                        .font(.system(size: 11)).frame(width: 24, height: 24).contentShape(Rectangle())
                }.help(quickPanel.overlayActionTitle).accessibilityLabel(quickPanel.overlayActionTitle).accessibilityIdentifier("overlay-quick-advice")
                Button { quickPanel.toggleOverlay() } label: {
                    Image(systemName: "rectangle.fill").font(.system(size: 11))
                        .frame(width: 24, height: 24).contentShape(Rectangle())
                }.help("退出透明，恢复普通卡片").accessibilityLabel("退出透明").accessibilityIdentifier("exit-overlay")
            }.buttonStyle(.plain).opacity(hovering ? 0.9 : 0.42)
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    if !state.enabled { Text("陪练已暂停").font(.system(size: 10)) }
                    if let warning = state.error ?? state.connectionError {
                        Text(warning).font(.system(size: 11)).foregroundStyle(Color(red: 1, green: 0.87, blue: 0.53))
                    }
                    if !state.advice.isEmpty {
                        Text("第 \(state.adviceTurn ?? 0) 回合" + (state.adviceTurn != state.snapshot?.turn ? " · 旧建议" : "") + (state.adviceComplete ? "" : " · 未完成"))
                            .font(.system(size: 10)).opacity(0.65)
                        Text((try? AttributedString(markdown: state.advice, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(state.advice))
                            .font(.system(size: 14, weight: .medium)).lineSpacing(4).textSelection(.enabled)
                    } else if let snap = state.snapshot {
                        ForEach(quickTips(snap).prefix(3)) { tip in
                            Text(tip.title).font(.system(size: 13, weight: .semibold))
                            Text(tip.detail).font(.system(size: 12)).lineSpacing(3)
                        }
                    } else {
                        Text("载入地图后，点 ✧ 获取建议。").font(.system(size: 12))
                    }
                    if state.generating { Text(state.phase).font(.system(size: 10)).opacity(0.7) }
                }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(.horizontal, 12).padding(.top, 9).padding(.bottom, 12)
            .frame(minWidth: 240, maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
            .foregroundStyle(.white).tint(.white)
            .shadow(color: .black, radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.85), radius: 3)
            // An almost invisible event surface makes blank pixels right-clickable.
            .background(Color.white.opacity(0.001))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(hovering ? 0.38 : 0.18),
                    style: StrokeStyle(lineWidth: 0.75, dash: [4, 4])).padding(3).allowsHitTesting(false)
            }
            .onHover { hovering = $0 }
    }
}

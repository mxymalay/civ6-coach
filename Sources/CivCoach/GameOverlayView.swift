import SwiftUI
import AppKit

/// A game HUD, not a translucent copy of the normal card.
struct GameOverlayView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @State private var hovering = false
    private var options: OverlayOptions { quickPanel.preferences.overlay }
    private var textFont: Font { .system(size: CGFloat(options.fontSize), weight: .medium, design: options.font.design) }

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
                    if quickPanel.guideVisible {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("透明小窗操作").font(.system(size: 12, weight: .semibold))
                            Label("拖动顶部移动，拖动四角缩放", systemImage: "arrow.up.left.and.arrow.down.right")
                            Label("右键：生成建议、文字设置、操作引导", systemImage: "cursorarrow.click.2")
                            Label("点右上角实心矩形或右键退出透明", systemImage: "rectangle.fill")
                            Button("知道了") { quickPanel.dismissGuide() }
                                .buttonStyle(CompactActionButton(prominent: true))
                        }.font(.system(size: 11)).foregroundStyle(.white)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
                    }
                    if let warning = state.error {
                        Label("详情见主窗口", systemImage: "exclamationmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 1, green: 0.87, blue: 0.53))
                            .lineLimit(1)
                            .help(warning)
                    }
                    if !state.advice.isEmpty {
                        Text("第 \(state.adviceTurn ?? 0) 回合" + (state.adviceTurn != state.snapshot?.turn ? " · 旧建议" : "") + (state.adviceComplete ? "" : " · 未完成"))
                            .font(.system(size: 10)).opacity(0.65)
                        Text((try? AttributedString(markdown: state.advice, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(state.advice))
                            .font(textFont)
                            .lineSpacing(4)
                            .lineLimit(5)
                            .truncationMode(.tail)
                            .textSelection(.enabled)
                    } else if let snap = state.snapshot {
                        ForEach(quickTips(snap).prefix(2)) { tip in
                            Text(tip.title)
                                .font(textFont)
                                .lineLimit(1)
                                .help(tip.detail)
                                .accessibilityLabel(tip.title + "。" + tip.detail)
                        }
                    } else {
                        Text("载入地图后，点 ✧ 获取建议。").font(textFont)
                    }
                    if state.generating { Text(state.phase).font(.system(size: 10)).opacity(0.7) }
                }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(.horizontal, 12).padding(.top, 9).padding(.bottom, 12)
            .frame(minWidth: 240, maxWidth: .infinity, minHeight: 120, maxHeight: .infinity)
            .foregroundStyle(options.color.value).tint(options.color.value)
            .shadow(color: .black.opacity(options.shadow.opacity), radius: options.shadow.radius, x: 0, y: 1)
            // An almost invisible event surface makes blank pixels right-clickable.
            .background(Color.white.opacity(0.001))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(hovering ? 0.38 : 0.18),
                    style: StrokeStyle(lineWidth: 0.75, dash: [4, 4])).padding(3).allowsHitTesting(false)
            }
            .overlay {
                // Dark under-stroke stays visible on bright game terrain;
                // the light inner stroke stays visible against dark terrain.
                OverlayCornerMarks().stroke(.black.opacity(hovering ? 0.85 : 0.65), lineWidth: 4)
                    .overlay(OverlayCornerMarks().stroke(.white.opacity(hovering ? 0.95 : 0.7), lineWidth: 1.5))
                    .allowsHitTesting(false)
            }
            .onHover { hovering = $0 }
    }
}

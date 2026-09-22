import SwiftUI
import AppKit

/// Text-only game HUD. The native panel must also be non-opaque and clear;
/// changing just this view's background would leave an opaque AppKit window.
struct GameOverlayView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @State private var controlsVisible = false

    private var status: String {
        if !state.enabled { return "陪练已暂停" }
        if state.connectionError != nil { return "未连接 · 下方内容可能已过时" }
        if let snap = state.snapshot { return "第 \(snap.turn) 回合" }
        return "等待读取游戏"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(status).font(.system(size: 11, weight: .medium))
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Button { state.setEnabled(!state.enabled) } label: {
                        Image(systemName: state.enabled ? "pause.fill" : "play.fill").frame(width: 28, height: 28)
                    }.help(state.enabled ? "暂停陪练" : "开启陪练").accessibilityLabel(state.enabled ? "暂停陪练" : "开启陪练")
                    Button { quickPanel.togglePin() } label: { Image(systemName: "pin.slash").frame(width: 28, height: 28) }
                        .help("取消固定，恢复完整小窗").accessibilityLabel("取消固定").accessibilityIdentifier("unpin-overlay")
                    Button { quickPanel.closePanel() } label: { Image(systemName: "xmark").frame(width: 28, height: 28) }
                        .help("收起叠加层").accessibilityLabel("收起叠加层")
                }.buttonStyle(.plain)
                    .opacity(controlsVisible ? 1 : 0)
                    .allowsHitTesting(controlsVisible)
                    .accessibilityHidden(!controlsVisible)
            }.frame(height: 30).contentShape(Rectangle())
                .onHover { controlsVisible = $0 }
                .help("拖动空白顶部移动小窗；移入顶部显示控制按钮")
                .background(OverlayDragHandle())
                .overlay(alignment: .top) {
                    if controlsVisible { Capsule().fill(.white.opacity(0.65)).frame(width: 24, height: 2).offset(y: -4).allowsHitTesting(false) }
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let warning = state.error ?? state.connectionError {
                        Text(warning).foregroundStyle(Color(red: 1, green: 0.87, blue: 0.53)).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    }
                    if !state.advice.isEmpty {
                        Text("建议依据：第 \(state.adviceTurn ?? 0) 回合" + (state.adviceTurn != state.snapshot?.turn ? " · 旧建议" : "") + (state.adviceComplete ? "" : " · 未完成"))
                            .font(.system(size: 11))
                        Text((try? AttributedString(markdown: state.advice, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(state.advice))
                            .font(.system(size: 15, weight: .medium)).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    } else if let snap = state.snapshot {
                        ForEach(quickTips(snap).prefix(3)) { tip in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title).font(.system(size: 15, weight: .semibold))
                                Text(tip.detail).font(.system(size: 13)).lineSpacing(4)
                            }
                        }
                    } else {
                        Text("边玩边看，按需问老师。\n点下方按钮开启陪练；移入顶部可取消固定，拖动顶部可移动。").font(.system(size: 14, weight: .medium)).lineSpacing(6)
                    }
                    if let from = state.turnChanges.fromTurn, let to = state.turnChanges.toTurn, !state.turnChanges.tips.isEmpty {
                        Text("回合变化 \(from) → \(to)").font(.system(size: 11))
                        ForEach(state.turnChanges.tips.prefix(3)) { Text("· " + $0.title).font(.system(size: 12, weight: .medium)) }
                    }
                    if state.generating { Text(state.phase).font(.system(size: 12)) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.vertical, 3)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 8) {
                Spacer()
                Button(action: quickAction) {
                    Text(actionTitle).font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 6)
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.9), lineWidth: 1))
                }.buttonStyle(.plain).accessibilityIdentifier("overlay-quick-advice")
                PanelResizeHandle().frame(width: 30, height: 30)
                    .overlay(Image(systemName: "arrow.down.right.and.arrow.up.left").font(.system(size: 12, weight: .semibold)).allowsHitTesting(false))
                    .help("拖动这里调整小窗大小")
            }
        }.padding(14).frame(minWidth: 300, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            .foregroundStyle(.white).tint(.white)
            .shadow(color: .black, radius: 1, x: 0, y: 1)
            .shadow(color: .black.opacity(0.85), radius: 3)
            .background(Color.clear)
    }
    private var actionTitle: String {
        if state.generating { return "停止生成" }
        if !state.enabled { return "开启陪练" }
        if !state.apiConfigured { return "配置 AI" }
        return "快速建议"
    }
    private func quickAction() {
        if state.generating { state.stopGeneration() }
        else if !state.enabled { state.setEnabled(true) }
        else if !state.apiConfigured { quickPanel.showMain(settings: true) }
        else { state.askAdvice() }
    }
}

/// A dedicated drag area works for a borderless panel without stealing clicks
/// from the foreground controls or selecting the advisory text.
private struct OverlayDragHandle: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

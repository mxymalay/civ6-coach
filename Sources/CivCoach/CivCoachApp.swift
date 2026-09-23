import SwiftUI
import AppKit

@main struct CivCoachApp: App {
    @StateObject private var state = AppState()
    @StateObject private var quickPanel = QuickPanelController()
    var body: some Scene {
        Window("文明 VI 陪练", id: "main") {
            CoachRootView().environmentObject(state).environmentObject(quickPanel)
        }.defaultSize(width: 1120, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) { Button("AI 与偏好设置…") { quickPanel.showMain(settings: true) }.keyboardShortcut(",", modifiers: .command) }
            CommandMenu("陪练") {
                Button("显示或收起快捷小窗") { quickPanel.togglePanel() }.keyboardShortcut("j", modifiers: [.command, .shift])
                Button(quickPanel.preferences.pinned ? "取消固定普通卡片" : "固定普通卡片") { quickPanel.togglePin() }.keyboardShortcut("o", modifiers: [.command, .shift])
                Button(quickPanel.preferences.transparent ? "退出透明叠加层" : "进入透明叠加层") { quickPanel.toggleOverlay() }.keyboardShortcut("g", modifiers: [.command, .shift])
                Button("一键 AI 建议") { state.askAdvice() }.disabled(state.generating).keyboardShortcut("j", modifiers: .command)
                Button("停止回答") { state.stopGeneration() }.disabled(!state.generating)
            }
        }
    }
}
private struct CoachRootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @Environment(\.openWindow) var openWindow
    @Environment(\.colorScheme) private var systemColorScheme
    private var themeStyle: AppThemeStyle {
        AppThemeStyle(accent: state.displayedTheme, appearance: state.displayedAppearance, systemColorScheme: systemColorScheme)
    }
    var body: some View {
        MainView().environment(\.coachTheme, themeStyle)
            .environment(\.colorScheme, themeStyle.colorScheme)
            .onAppear { quickPanel.install(state: state, openMain: { openWindow(id: "main") }) }
    }
}
struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @Environment(\.coachTheme) var theme
    private var palette: ThemePalette { theme.palette }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: "globe.asia.australia.fill").foregroundStyle(palette.mint)
                Text("文明陪练").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button { quickPanel.togglePin() } label: {
                    Image(systemName: quickPanel.preferences.pinned ? "pin.fill" : "pin")
                        .foregroundStyle(quickPanel.preferences.pinned ? palette.mint : palette.secondary)
                        .frame(width: 26, height: 26)
                }.buttonStyle(.plain).help(quickPanel.preferences.pinned ? "取消固定：点击外部自动收起" : "固定小窗：持续置顶")
                    .accessibilityLabel("固定小窗").accessibilityValue(quickPanel.preferences.pinned ? "已固定" : "未固定").accessibilityIdentifier("pin-panel")
                Button { quickPanel.toggleOverlay() } label: {
                    Image(systemName: "rectangle.dashed").foregroundStyle(palette.secondary).frame(width: 24, height: 26)
                }.buttonStyle(.plain).help("透明游戏叠加层 · 自动置顶").accessibilityLabel("进入透明叠加层").accessibilityIdentifier("enter-overlay")
                Button { quickPanel.closePanel() } label: { Image(systemName: "xmark").foregroundStyle(palette.secondary).frame(width: 24, height: 26) }.buttonStyle(.plain).help("收起小窗").accessibilityLabel("收起小窗")
            }
            Text(state.status).font(.system(size: 11)).foregroundStyle(palette.secondary)
            if let snap = state.snapshot {
                HStack { Text("第 \(snap.turn) 回合").fontWeight(.semibold); Spacer(); Text("\(snap.cities.count) 城 · \(snap.units.count) 单位") }.font(.system(size: 12))
            }
            if let message = state.error { Text(message).font(.system(size: 11)).foregroundStyle(palette.gold).lineLimit(2).help(message) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let from = state.turnChanges.fromTurn, let to = state.turnChanges.toTurn, !state.turnChanges.tips.isEmpty {
                        Text("回合变化 · \(from) → \(to)").font(.system(size: 11, weight: .semibold))
                        ForEach(state.turnChanges.tips.prefix(3)) { tip in
                            Text(tip.title).font(.system(size: 11)).foregroundStyle(tip.urgent ? palette.gold : palette.secondary)
                        }
                        Divider()
                    }
                    if !state.advice.isEmpty {
                        Text("AI 建议 · 第 \(state.adviceTurn ?? 0) 回合" + (state.adviceComplete ? "" : " · 未完成")).font(.system(size: 10)).foregroundStyle(palette.secondary)
                        MarkdownText(text: state.advice)
                    } else if let snap = state.snapshot {
                        Text("即时提醒 · 无需 AI").font(.system(size: 10)).foregroundStyle(palette.secondary)
                        ForEach(quickTips(snap)) { tip in
                            VStack(alignment: .leading, spacing: 5) {
                                Label(tip.title, systemImage: tip.icon).font(.system(size: 12, weight: .medium))
                                Text(tip.detail).font(.system(size: 11)).foregroundStyle(palette.secondary)
                            }
                        }
                    } else {
                        Text("载入游戏地图，即可在这里查看提醒和获取建议。").font(.system(size: 12)).foregroundStyle(palette.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            }.frame(minHeight: 70, maxHeight: .infinity).background(palette.card, in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 8) {
                Button { quickPanel.showMain(chat: true) } label: { Image(systemName: "bubble.left.and.bubble.right").frame(width: 24, height: 24) }
                    .help("聊一聊").accessibilityLabel("聊一聊")
                Button { quickPanel.showMain(settings: true) } label: { Image(systemName: "gearshape").frame(width: 24, height: 24) }
                    .help("设置").accessibilityLabel("设置")
                Spacer()
                if state.generating {
                    ProgressView().controlSize(.mini)
                    Button("停止") { state.stopGeneration() }.buttonStyle(CompactActionButton()).help(state.phase)
                } else {
                    Button {
                        if state.apiConfigured { state.askAdvice() } else { quickPanel.showMain(settings: true) }
                    } label: { Label("建议", systemImage: "sparkles") }
                        .buttonStyle(CompactActionButton(prominent: true))
                }
            }.buttonStyle(CompactActionButton()).font(.system(size: 12))
        }.padding(12).frame(minWidth: 320, maxWidth: .infinity, minHeight: 280, maxHeight: .infinity).background(palette.background).foregroundStyle(palette.primary)
    }
}

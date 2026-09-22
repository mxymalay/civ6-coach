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
                Button(state.enabled ? "暂停陪练" : "开启陪练") { state.setEnabled(!state.enabled) }.keyboardShortcut("p", modifiers: [.command, .shift])
                Button("一键 AI 建议") { state.askAdvice() }.disabled(!state.enabled || state.generating).keyboardShortcut("j", modifiers: .command)
                Button("停止回答") { state.stopGeneration() }.disabled(!state.generating)
            }
        }
    }
}
private struct CoachRootView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @Environment(\.openWindow) var openWindow
    var body: some View {
        MainView().environment(\.coachTheme, state.settings.theme)
            .onAppear { quickPanel.install(state: state, openMain: { openWindow(id: "main") }) }
    }
}
struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @Environment(\.coachTheme) var theme
    private var palette: ThemePalette { theme.palette }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "globe.asia.australia.fill").foregroundStyle(palette.mint)
                Text("文明 VI 陪练").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button { quickPanel.togglePin() } label: {
                    Image(systemName: quickPanel.preferences.pinned ? "pin.fill" : "pin")
                        .foregroundStyle(quickPanel.preferences.pinned ? palette.mint : palette.secondary)
                        .frame(width: 26, height: 26)
                }.buttonStyle(.plain).help(quickPanel.preferences.pinned ? "取消固定：点击外部自动收起" : "固定小窗：持续置顶")
                    .accessibilityLabel("固定小窗").accessibilityValue(quickPanel.preferences.pinned ? "已固定" : "未固定").accessibilityIdentifier("pin-panel")
                Button { quickPanel.closePanel() } label: { Image(systemName: "xmark").foregroundStyle(palette.secondary).frame(width: 24, height: 26) }.buttonStyle(.plain).help("收起小窗").accessibilityLabel("收起小窗")
            }
            HStack {
                Text(state.status).font(.system(size: 11)).foregroundStyle(palette.secondary)
                Spacer()
                Toggle("开启陪练", isOn: Binding(get: { state.enabled }, set: { state.setEnabled($0) })).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(palette.mint)
            }
            if let snap = state.snapshot {
                HStack { Text("第 \(snap.turn) 回合").fontWeight(.semibold); Spacer(); Text("\(snap.cities.count) 城 · \(snap.units.count) 单位") }.font(.system(size: 12))
            }
            if let message = state.error ?? state.connectionError { Text(message).font(.system(size: 11)).foregroundStyle(palette.gold).lineLimit(4) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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
                        Text("载入游戏地图并开启陪练，即可在这里查看提醒和获取建议。").font(.system(size: 12)).foregroundStyle(palette.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }.frame(minHeight: 100, maxHeight: .infinity).background(palette.card, in: RoundedRectangle(cornerRadius: 12))
            if state.generating {
                HStack { ProgressView().controlSize(.small); Text(state.phase).font(.system(size: 11)); Spacer(); Button("停止") { state.stopGeneration() }.buttonStyle(QuietButton()) }
            } else {
                Button { if state.apiConfigured { state.askAdvice() } else { quickPanel.showMain(settings: true) } } label: { Label("快速给我建议", systemImage: "sparkles").frame(maxWidth: .infinity) }.buttonStyle(PrimaryButton()).disabled(!state.enabled)
            }
            HStack {
                Button("聊一聊") { quickPanel.showMain(chat: true) }.buttonStyle(QuietButton())
                Button("设置") { quickPanel.showMain(settings: true) }.buttonStyle(QuietButton())
                Spacer()
                Button("退出") { state.setEnabled(false); NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(palette.secondary)
            }
        }.padding(18).frame(minWidth: 360, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity).background(palette.background).foregroundStyle(palette.primary).preferredColorScheme(theme.colorScheme)
    }
}

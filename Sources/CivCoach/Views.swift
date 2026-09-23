import SwiftUI
import AppKit

struct Card<Content: View>: View {
    @Environment(\.coachTheme) private var theme
    private var palette: ThemePalette { theme.palette }
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(palette.card, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.line)) }
}
struct PrimaryButton: ButtonStyle {
    @Environment(\.coachTheme) private var theme
    private var palette: ThemePalette { theme.palette }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(palette.buttonText).background(palette.mint.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct QuietButton: ButtonStyle {
    @Environment(\.coachTheme) private var theme
    private var palette: ThemePalette { theme.palette }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 9)
            .foregroundStyle(palette.primary.opacity(configuration.isPressed ? 0.6 : 0.86)).background(palette.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 9))
    }
}
struct CompactActionButton: ButtonStyle {
    @Environment(\.coachTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .foregroundStyle(prominent ? theme.palette.mint : theme.palette.secondary)
            .background((prominent ? theme.palette.mint : theme.palette.primary).opacity(configuration.isPressed ? 0.16 : 0.07), in: RoundedRectangle(cornerRadius: 7))
            .opacity(enabled ? 1 : 0.4)
    }
}

struct APIProfileMenu: View {
    @Environment(\.coachTheme) private var theme
    let profiles: [APIProfile]
    let selectedID: UUID
    let onSelect: (UUID) -> Void
    var compact = false
    private var selected: APIProfile? { profiles.first { $0.id == selectedID } }
    var body: some View {
        Menu {
            ForEach(profiles) { profile in
                Button { onSelect(profile.id) } label: {
                    if profile.id == selectedID { Label(profile.displayName, systemImage: "checkmark") }
                    else { Text(profile.displayName) }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "server.rack").foregroundStyle(theme.palette.mint)
                Text((selected?.displayName ?? "API") + (compact && !(selected?.model.isEmpty ?? true) ? " · " + (selected?.model ?? "") : "")).lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }.font(.system(size: 11, weight: .medium)).foregroundStyle(theme.palette.primary)
                .padding(.horizontal, compact ? 0 : 10).padding(.vertical, compact ? 3 : 9)
                .background(compact ? Color.clear : theme.palette.sidebar, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(compact ? Color.clear : theme.palette.line))
        }.menuStyle(.borderlessButton).menuIndicator(.hidden)
            .help("切换 API 配置").accessibilityLabel("API 配置")
    }
}

struct CoachInputStyle: ViewModifier {
    @Environment(\.coachTheme) private var theme
    var focused: Bool
    var fill: Color? = nil
    private var palette: ThemePalette { theme.palette }

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(palette.primary)
            .tint(palette.mint)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(fill ?? palette.sidebar, in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(focused ? palette.mint.opacity(0.85) : palette.secondary.opacity(0.24), lineWidth: focused ? 1.5 : 1)
            }
            .shadow(color: focused ? palette.mint.opacity(0.11) : .clear, radius: 5)
    }
}

struct CoachChoiceBar<Choice: Hashable>: View {
    @Environment(\.coachTheme) private var theme
    @Binding var selection: Choice
    let choices: [Choice]
    let title: (Choice) -> String
    private var palette: ThemePalette { theme.palette }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(choices, id: \.self) { choice in
                let selected = selection == choice
                Button { selection = choice } label: {
                    Text(title(choice))
                        .font(.system(size: 11, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? palette.mint : palette.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(selected ? palette.card : .clear, in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(selected ? palette.mint.opacity(0.38) : .clear)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(choice))
                .accessibilityValue(selected ? "已选择" : "未选择")
            }
        }
        .padding(3)
        .background(palette.sidebar, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(palette.secondary.opacity(0.16)))
    }
}
struct MainView: View {
    @Environment(\.coachTheme) private var theme
    private var palette: ThemePalette { theme.palette }
    @EnvironmentObject var state: AppState
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 238)
            Rectangle().fill(palette.line).frame(width: 1)
            VStack(spacing: 0) {
                header
                if let error = state.error {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(palette.gold)
                        Text(error).font(.system(size: 12)).textSelection(.enabled)
                        Spacer()
                        Button { state.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.padding(12).background(palette.gold.opacity(0.10))
                }
                if state.selectedTab == "和老师聊聊" { ChatView() }
                else { dashboard }
            }
        }
        .background(palette.background)
        .foregroundStyle(palette.primary.opacity(0.93))
        .frame(minWidth: 980, minHeight: 690)
        .preferredColorScheme(theme.colorScheme)
        .sheet(isPresented: $state.settingsOpen) { SettingsView().environmentObject(state) }
        .background(WindowAccessor { window in
            window.identifier = NSUserInterfaceItemIdentifier("coach-main")
            window.level = state.settings.alwaysOnTop ? .floating : .normal
            window.backgroundColor = NSColor(palette.background)
        })
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "globe.asia.australia.fill").font(.system(size: 29, weight: .light)).foregroundStyle(palette.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("文明 VI 陪练").font(.system(size: 17, weight: .semibold))
                }
            }.padding(.top, 25).padding(.bottom, 14)
            VStack(spacing: 7) {
                navItem("局势与建议", icon: "square.grid.2x2")
                navItem("和老师聊聊", icon: "bubble.left.and.bubble.right")
            }.padding(.top, 2)
            Rectangle().fill(palette.line).frame(height: 1).padding(.vertical, 16)
            Text("当前对局").font(.system(size: 10, weight: .semibold)).foregroundStyle(palette.secondary)
            if let snap = state.snapshot {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snap.meta.text("civilization")).font(.system(size: 18, weight: .medium, design: .serif)).foregroundStyle(palette.gold)
                    Text("第 \(snap.turn) 回合 · \(snap.cities.count) 城").font(.system(size: 11)).foregroundStyle(palette.secondary)
                }.padding(.top, 16)
            } else {
                Text("未连接").font(.system(size: 11)).foregroundStyle(palette.secondary).padding(.top, 16)
            }
            Spacer(minLength: 18)
            VStack(alignment: .leading, spacing: 12) {
                Button { state.settingsOpen = true } label: {
                    HStack { Image(systemName: "slider.horizontal.3"); Text("AI 与偏好设置"); Spacer(); Image(systemName: "chevron.right").font(.system(size: 9)) }
                }.buttonStyle(QuietButton()).accessibilityIdentifier("settings-button")
            }.padding(.bottom, 22)
        }.padding(.horizontal, 19).frame(maxHeight: .infinity).background(palette.sidebar)
    }
    private func navItem(_ title: String, icon: String) -> some View {
        Button { state.selectedTab = title } label: {
            HStack(spacing: 12) { Image(systemName: icon).frame(width: 18); Text(title); Spacer(); if state.selectedTab == title { Circle().fill(palette.mint).frame(width: 5) } }
                .font(.system(size: 13, weight: .medium)).padding(13)
                .foregroundStyle(state.selectedTab == title ? palette.mint : palette.secondary)
                .background(state.selectedTab == title ? palette.mint.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(state.selectedTab + (AppState.isQA ? " · 验证模式" : "")).font(.system(size: 15, weight: .semibold))
                if let snap = state.snapshot {
                    Text("第 \(snap.turn) 回合快照 · \(snap.capturedAt.formatted(date: .omitted, time: .standard))" + (state.live ? " 更新" : " · 非实时"))
                        .font(.system(size: 10)).foregroundStyle(palette.secondary)
                } else { Text(state.status).font(.system(size: 10)).foregroundStyle(palette.secondary) }
            }
            Spacer()
            if state.generating { ProgressView().controlSize(.small); Text(state.phase).font(.system(size: 11)).foregroundStyle(palette.secondary) }
            Button { state.refresh() } label: { Label(state.refreshing ? "读取中" : "刷新局势", systemImage: "arrow.clockwise") }
                .buttonStyle(QuietButton()).disabled(state.refreshing || state.generating).keyboardShortcut("r", modifiers: .command)
            Button { state.toggleMainPin() } label: {
                Image(systemName: state.settings.alwaysOnTop ? "pin.fill" : "pin")
                    .foregroundStyle(state.settings.alwaysOnTop ? palette.mint : palette.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(state.settings.alwaysOnTop ? "取消固定主窗口" : "固定主窗口：保持在最前面")
            .accessibilityLabel("固定主窗口")
            .accessibilityValue(state.settings.alwaysOnTop ? "已固定" : "未固定")
            .accessibilityIdentifier("pin-main")
        }.padding(.horizontal, 28).padding(.vertical, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
    }
    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let snap = state.snapshot {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snap.meta.text("civilization")).font(.system(size: 19, weight: .semibold, design: .serif))
                            Text("第 \(snap.turn) 回合 · \(snap.cities.count) 城 · \(snap.units.count) 部队")
                                .font(.system(size: 11)).foregroundStyle(palette.secondary)
                        }
                        Spacer()
                        HStack(spacing: 5) {
                            Circle().fill(state.live ? palette.mint : palette.secondary).frame(width: 6, height: 6)
                            Text(state.live ? "实时" : "等待连接").font(.system(size: 10)).foregroundStyle(palette.secondary)
                        }
                        Button { state.refresh() } label: {
                            Image(systemName: state.refreshing ? "hourglass" : "arrow.clockwise").frame(width: 28, height: 28)
                        }.buttonStyle(.plain).help("刷新局势").disabled(state.refreshing || state.generating)
                    }.padding(.bottom, 2)

                    HStack(spacing: 9) {
                        compactMetric("金币", value: snap.economy.display("gold"), detail: snap.economy.display("gold_net_per_turn") + "/回合", icon: "circle.circle", color: palette.gold)
                        compactMetric("科研", value: snap.economy.display("science_per_turn"), detail: "每回合", icon: "flask", color: palette.mint)
                        compactMetric("文化", value: snap.economy.display("culture_per_turn"), detail: "每回合", icon: "building.columns", color: .purple.opacity(0.85))
                        compactMetric("信仰", value: snap.economy.display("faith"), detail: "储备", icon: "sun.max", color: palette.secondary)
                    }

                    if !state.turnChanges.tips.isEmpty {
                        sectionTitle("回合变化")
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(state.turnChanges.tips.prefix(2)) { tip in
                                HStack(spacing: 8) {
                                    Image(systemName: tip.icon).foregroundStyle(tip.urgent ? palette.gold : palette.mint)
                                    Text(tip.title).lineLimit(1)
                                    Spacer(minLength: 0)
                                }.font(.system(size: 11))
                            }
                        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(palette.card, in: RoundedRectangle(cornerRadius: 10))
                    }

                    sectionTitle("提醒")
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(quickTips(snap).prefix(3).enumerated()), id: \.offset) { index, tip in
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: tip.icon).foregroundStyle(tip.urgent ? palette.gold : palette.mint)
                                    .frame(width: 17).padding(.top, 1)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tip.title).font(.system(size: 12, weight: .medium))
                                    Text(tip.detail).font(.system(size: 10)).foregroundStyle(palette.secondary).lineLimit(2)
                                }
                                Spacer(minLength: 0)
                                if tip.urgent { Text("优先").font(.system(size: 9)).foregroundStyle(palette.gold) }
                            }.padding(.vertical, 9)
                            if index < min(quickTips(snap).count, 3) - 1 {
                                Rectangle().fill(palette.line).frame(height: 1).padding(.leading, 26)
                            }
                        }
                    }.padding(.horizontal, 12).background(palette.card, in: RoundedRectangle(cornerRadius: 10))

                    if snap.errors > 0 {
                        Text("\(snap.errors) 项数据暂不可用").font(.system(size: 10)).foregroundStyle(palette.gold)
                    }
                } else {
                    HStack(spacing: 13) {
                        Image(systemName: "map").font(.system(size: 25)).foregroundStyle(palette.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("还没连接对局").font(.system(size: 14, weight: .medium))
                            Text("进入单人地图后自动连接").font(.system(size: 11)).foregroundStyle(palette.secondary)
                        }
                        Spacer()
                    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.card, in: RoundedRectangle(cornerRadius: 11))
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("老师建议", systemImage: "sparkles").font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.mint)
                        Spacer()
                        if let turn = state.adviceTurn {
                            Text("第 \(turn) 回合" + (turn != state.snapshot?.turn ? " · 旧" : ""))
                                .font(.system(size: 10)).foregroundStyle(palette.secondary)
                        }
                        if !state.advice.isEmpty {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(state.advice, forType: .string)
                            } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("复制建议")
                        }
                    }
                    if !state.advice.isEmpty {
                        MarkdownText(text: state.advice)
                    } else {
                        Text(advicePlaceholder).font(.system(size: 11)).foregroundStyle(palette.secondary)
                    }
                    HStack {
                        Spacer()
                        Button(action: dashboardAdviceAction) {
                            if state.generating { Label("停止", systemImage: "stop.fill") }
                            else { Label(adviceButtonTitle, systemImage: "sparkles") }
                        }.buttonStyle(QuietButton())
                            .accessibilityIdentifier("advice-button")
                    }
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 11))
            }.padding(22)
        }
    }
    private var advicePlaceholder: String {
        if state.generating { return state.phase }
        if !state.apiConfigured { return "连接 AI 后，可让老师结合当前局势给建议。" }
        if state.snapshot == nil { return "进入对局后，即可根据当前局势生成建议。" }
        return "根据当前局势，给你一个下一步建议。"
    }
    private var adviceButtonTitle: String {
        if !state.apiConfigured { return "配置 AI" }
        return "生成建议"
    }
    private func dashboardAdviceAction() {
        if state.generating { state.stopGeneration() }
        else if !state.apiConfigured { state.settingsOpen = true }
        else { state.askAdvice() }
    }
    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.secondary)
    }
    private func compactMetric(_ title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).foregroundStyle(palette.secondary)
            }.font(.system(size: 10))
            Text(value).font(.system(size: 18, weight: .medium, design: .rounded)).monospacedDigit()
            Text(detail).font(.system(size: 9)).foregroundStyle(palette.secondary).lineLimit(1)
        }.padding(11).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct MarkdownText: View {
    @Environment(\.coachTheme) private var theme
    private var palette: ThemePalette { theme.palette }
    var text: String
    var body: some View {
        Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
            .font(.system(size: 13)).lineSpacing(7).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).tint(palette.mint)
    }
}

struct ChatView: View {
    @Environment(\.coachTheme) private var theme
    private var palette: ThemePalette { theme.palette }
    @EnvironmentObject var state: AppState
    @FocusState private var inputFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("导出") { state.exportChat() }.buttonStyle(QuietButton()).disabled(state.messages.isEmpty)
                Button("新对话") { state.archiveAndClear() }.buttonStyle(QuietButton()).disabled(state.generating)
            }.padding(.horizontal, 26).padding(.vertical, 14)
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if state.messages.isEmpty {
                            VStack(alignment: .leading, spacing: 18) {
                                Image(systemName: "bubble.left.and.text.bubble.right").font(.system(size: 39, weight: .light)).foregroundStyle(palette.mint)
                                Text("你想先弄懂什么？").font(.system(size: 25, weight: .medium, design: .serif))
                                ForEach(["我现在最应该做什么？", "首都下一步造什么？解释一下原因。", "怎么判断第二座城市建在哪里？"], id: \.self) { text in
                                    Button { state.draft = text } label: { HStack { Text(text); Spacer(); Image(systemName: "arrow.up.left") } }.buttonStyle(QuietButton())
                                }
                            }.padding(.vertical, 30).frame(maxWidth: 470, alignment: .leading)
                        }
                        ForEach(state.messages) { msg in
                            messageRow(msg).id(msg.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(.horizontal, 26).padding(.vertical, 16)
                }
                .onChange(of: state.messages.count) { _ in reader.scrollTo("bottom", anchor: .bottom) }
            }
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("问问老师：为什么现在应该这样做？", text: $state.draft, axis: .vertical)
                        .lineLimit(2...5).focused($inputFocused)
                        .modifier(CoachInputStyle(focused: inputFocused, fill: palette.card))
                        .accessibilityIdentifier("chat-input")
                    if state.generating {
                        Button { state.stopGeneration() } label: { Image(systemName: "stop.fill").frame(width: 20, height: 24) }.buttonStyle(PrimaryButton()).help("停止生成")
                    } else {
                        Button { state.sendDraft() } label: { Image(systemName: "arrow.up").frame(width: 20, height: 24) }.buttonStyle(PrimaryButton()).disabled(state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.return, modifiers: .command).help("发送 ⌘↩").accessibilityIdentifier("send-chat")
                    }
                }
                HStack {
                    APIProfileMenu(profiles: state.settings.apiProfiles, selectedID: state.settings.selectedAPIID, onSelect: state.selectAPIProfile, compact: true)
                        .frame(maxWidth: 260).disabled(state.generating || state.testing)
                    Spacer()
                    Text("⌘ ↩ 发送 · 每次发送前刷新局势")
                }.font(.system(size: 9)).foregroundStyle(palette.secondary)
            }.padding(22).background(palette.sidebar.opacity(0.5))
        }
    }
    private func messageRow(_ message: ChatMessage) -> some View {
        let fromUser = message.role == "user"
        return HStack(alignment: .top, spacing: 10) {
            if fromUser { Spacer(minLength: 40) }
            else { messageAvatar(fromUser: false) }
            messageBubble(message, fromUser: fromUser)
                .frame(maxWidth: fromUser ? 500 : 600, alignment: .leading)
            if fromUser { messageAvatar(fromUser: true) }
            else { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity)
    }
    private func messageAvatar(fromUser: Bool) -> some View {
        Image(systemName: fromUser ? "person.crop.circle.fill" : "sparkles")
            .font(.system(size: 18))
            .foregroundStyle(fromUser ? palette.mint : palette.secondary)
            .frame(width: 28, height: 28)
            .padding(.top, 3)
            .accessibilityHidden(true)
    }
    private func messageBubble(_ message: ChatMessage, fromUser: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(fromUser ? "你" : "文明陪练")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                if message.interrupted { Text("未完成").font(.system(size: 9)).foregroundStyle(palette.gold) }
                Spacer(minLength: 8)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(palette.secondary)
                }.buttonStyle(.plain).help("复制消息")
            }
            if message.text.isEmpty { Text(state.phase).font(.system(size: 12)).foregroundStyle(palette.secondary) }
            else { MarkdownText(text: message.text) }
        }
        .padding(15)
        .background(fromUser ? palette.mint.opacity(0.12) : palette.card, in: RoundedRectangle(cornerRadius: 13))
    }
}

struct WindowAccessor: NSViewRepresentable {
    let action: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { if let window = view.window { action(window) } }; return view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

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
                    Text("每一步，都有思路").font(.system(size: 10)).tracking(2).foregroundStyle(palette.secondary)
                }
            }.padding(.top, 28).padding(.bottom, 30)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("陪练开关").font(.system(size: 13, weight: .medium))
                    Text(state.enabled ? "正在留意你的局势" : "按需开启，随时暂停").font(.system(size: 10)).foregroundStyle(palette.secondary)
                }
                Spacer()
                Toggle("开启陪练", isOn: Binding(get: { state.enabled }, set: { state.setEnabled($0) })).labelsHidden().toggleStyle(.switch).tint(palette.mint).controlSize(.small)
                    .accessibilityIdentifier("coach-toggle")
            }.padding(14).background(palette.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 7) {
                navItem("局势与建议", icon: "square.grid.2x2")
                navItem("和老师聊聊", icon: "bubble.left.and.bubble.right")
            }.padding(.top, 26)
            Rectangle().fill(palette.line).frame(height: 1).padding(.vertical, 23)
            Text("当前对局").font(.system(size: 10, weight: .semibold)).foregroundStyle(palette.secondary).tracking(2)
            if let snap = state.snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    Text(snap.meta.text("civilization")).font(.system(size: 23, weight: .medium, design: .serif)).foregroundStyle(palette.gold)
                    Text(snap.meta.text("leader") + " · 第 \(snap.turn) 回合").font(.system(size: 12)).foregroundStyle(palette.secondary)
                    HStack { Label("\(snap.cities.count) 座城市", systemImage: "building.2"); Spacer(); Label("\(snap.units.count) 支部队", systemImage: "flag") }.font(.system(size: 10)).foregroundStyle(palette.secondary)
                }.padding(.top, 16)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "map").font(.system(size: 25, weight: .ultraLight)).foregroundStyle(palette.secondary)
                    Text("等待你的文明").font(.system(size: 14))
                    Text("进入单人地图，再开启陪练。\n无需截图，直接读取局势。").font(.system(size: 11)).foregroundStyle(palette.secondary).lineSpacing(4)
                }.padding(.top, 16)
            }
            Spacer(minLength: 18)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Circle().fill(state.live ? palette.mint : palette.secondary).frame(width: 6, height: 6)
                    Text(state.status).font(.system(size: 10)).foregroundStyle(palette.secondary)
                }
                Button { state.settingsOpen = true } label: {
                    HStack { Image(systemName: "slider.horizontal.3"); Text("AI 与偏好设置"); Spacer(); Image(systemName: "chevron.right").font(.system(size: 9)) }
                }.buttonStyle(QuietButton()).accessibilityIdentifier("settings-button")
                Text("只读你的局势 · 决定由你来做").font(.system(size: 9)).foregroundStyle(palette.secondary.opacity(0.7))
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
                } else { Text("你的回合，你的节奏").font(.system(size: 10)).foregroundStyle(palette.secondary) }
            }
            Spacer()
            if state.generating { ProgressView().controlSize(.small); Text(state.phase).font(.system(size: 11)).foregroundStyle(palette.secondary) }
            Button { state.refresh() } label: { Label(state.refreshing ? "读取中" : "刷新局势", systemImage: "arrow.clockwise") }
                .buttonStyle(QuietButton()).disabled(!state.enabled || state.refreshing || state.generating).keyboardShortcut("r", modifiers: .command)
        }.padding(.horizontal, 28).padding(.vertical, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.line).frame(height: 1) }
    }
    private var dashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("下一步，走得更从容。").font(.system(size: 27, weight: .medium, design: .serif))
                        Text("看清局势，理解取舍，再做决定。").font(.system(size: 12)).foregroundStyle(palette.secondary)
                    }
                    Spacer()
                    Button { state.askAdvice() } label: { Label("一键 AI 建议", systemImage: "sparkles") }
                        .buttonStyle(PrimaryButton()).disabled(!state.enabled || state.generating)
                        .accessibilityIdentifier("advice-button")
                }.padding(.top, 6)
                if !state.enabled {
                    infoBanner("陪练已暂停", detail: "打开左侧开关后自动读取游戏。暂停会停止读取与 AI 请求。", icon: "pause.circle")
                } else if let err = state.connectionError {
                    infoBanner("还没连上游戏", detail: err, icon: "link")
                }
                if !state.apiConfigured {
                    HStack(spacing: 12) {
                        Image(systemName: "key.horizontal").foregroundStyle(palette.gold)
                        VStack(alignment: .leading, spacing: 4) { Text("接入你的 AI").font(.system(size: 12, weight: .medium)); Text("连接 Codex 或自定义 API，解锁分析与对话；基础提醒无需 AI。").font(.system(size: 11)).foregroundStyle(palette.secondary) }
                        Spacer()
                        Button("去配置") { state.settingsOpen = true }.buttonStyle(QuietButton())
                    }.padding(16).background(palette.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }
                if let snap = state.snapshot {
                    HStack(spacing: 12) {
                        stat("国库", value: snap.economy.display("gold"), detail: "净收入 " + snap.economy.display("gold_net_per_turn") + "/回合", icon: "circle.circle", color: palette.gold)
                        stat("科技", value: snap.economy.display("science_per_turn"), detail: "每回合科研产出", icon: "flask", color: .cyan.opacity(0.8))
                        stat("文化", value: snap.economy.display("culture_per_turn"), detail: "每回合文化产出", icon: "building.columns", color: .purple.opacity(0.85))
                        stat("信仰", value: snap.economy.display("faith"), detail: "当前信仰储备", icon: "sun.max", color: palette.mint)
                    }
                    HStack { Text("先留意这几件事").font(.system(size: 14, weight: .semibold)); Spacer(); Text("本地基础提醒 · 无 API 消耗").font(.system(size: 10)).foregroundStyle(palette.secondary) }
                    VStack(spacing: 10) {
                        ForEach(quickTips(snap)) { tip in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: tip.icon).font(.system(size: 16)).foregroundStyle(tip.urgent ? palette.gold : palette.mint).frame(width: 34, height: 34).background(palette.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 6) { Text(tip.title).font(.system(size: 13, weight: .medium)); Text(tip.detail).font(.system(size: 11)).foregroundStyle(palette.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true) }
                                Spacer()
                                if tip.urgent { Text("优先").font(.system(size: 9)).foregroundStyle(palette.gold).padding(5).background(palette.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 5)) }
                            }.padding(15).background(palette.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    if snap.errors > 0 { Text("有 \(snap.errors) 项数据暂不可用，建议会保留不确定性。").font(.system(size: 11)).foregroundStyle(palette.gold) }
                } else {
                    Card {
                        HStack(spacing: 25) {
                            Image(systemName: "map.circle").font(.system(size: 65, weight: .ultraLight)).foregroundStyle(palette.mint.opacity(0.55))
                            VStack(alignment: .leading, spacing: 12) {
                                Text("从这一回合开始").font(.system(size: 20, weight: .medium, design: .serif))
                                Text("1  进入《文明 VI》的单人地图\n2  开启陪练，读取你的城市与部队\n3  点一下建议，或者直接问老师").font(.system(size: 12)).foregroundStyle(palette.secondary).lineSpacing(10)
                            }
                            Spacer()
                        }.padding(.vertical, 22)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Label("老师的建议", systemImage: "sparkles").font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.mint)
                            Spacer()
                            if let turn = state.adviceTurn { Text("依据第 \(turn) 回合" + (turn != state.snapshot?.turn ? " · 旧建议" : "") + (!state.adviceComplete && !state.advice.isEmpty ? " · 未完成" : "")).font(.system(size: 10)).foregroundStyle(palette.secondary) }
                            if !state.advice.isEmpty { Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(state.advice, forType: .string) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("复制建议") }
                        }
                        if state.advice.isEmpty { Text(state.generating && state.selectedTab == "局势与建议" ? state.phase : "让老师结合当前局势，给你一个有理由的下一步。\n可以随时停止；Codex 通常在思考完成后显示回复。").font(.system(size: 12)).foregroundStyle(palette.secondary).lineSpacing(6).padding(.vertical, 8) }
                        else { MarkdownText(text: state.advice) }
                        HStack {
                            if state.generating { Button("停止生成") { state.stopGeneration() }.buttonStyle(QuietButton()) }
                            Spacer()
                            Button { state.selectedTab = "和老师聊聊"; state.draft = "请解释刚才建议的取舍。" } label: { Label("继续讨论", systemImage: "arrow.up.right") }.buttonStyle(QuietButton())
                        }
                    }
                }
                if let snap = state.snapshot, !snap.cities.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text("城市速览").font(.system(size: 14, weight: .semibold)); Spacer(); Text("人口 / 住房 · 当前生产").font(.system(size: 10)).foregroundStyle(palette.secondary) }
                        ForEach(Array(snap.cities.enumerated()), id: \.offset) { _,city in
                            HStack {
                                Image(systemName: "building.2.crop.circle").font(.system(size: 24)).foregroundStyle(palette.gold)
                                Text(city.text("name")).font(.system(size: 12, weight: .medium))
                                Text(city.display("population") + " / " + city.display("housing")).font(.system(size: 11)).foregroundStyle(palette.secondary)
                                Spacer()
                                Text(city.text("production")).font(.system(size: 12))
                                if let turns = city.int("production_turns"), turns >= 0 { Text("\(turns) 回合").font(.system(size: 10)).foregroundStyle(palette.secondary) }
                            }.padding(14).background(palette.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 11))
                        }
                    }
                }
                Text("游戏读取仅在本机进行。点击 AI 建议或发送消息时，相关局势会发送到你选择的 AI 服务。").font(.system(size: 10)).foregroundStyle(palette.secondary.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
            }.padding(28)
        }
    }
    private func stat(_ title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: icon).foregroundStyle(color); Text(title).foregroundStyle(palette.secondary) }.font(.system(size: 11))
            Text(value).font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
            Text(detail).font(.system(size: 9)).foregroundStyle(palette.secondary).lineLimit(1)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(palette.card, in: RoundedRectangle(cornerRadius: 13))
    }
    private func infoBanner(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).foregroundStyle(palette.secondary); VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 12, weight: .medium)); Text(detail).font(.system(size: 11)).foregroundStyle(palette.secondary) }; Spacer() }.padding(15).background(palette.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
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
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("边玩边问，把每个选择想明白。").font(.system(size: 11)).foregroundStyle(palette.secondary)
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
                                Text("老师会结合刚读取的局势回答，并记住这段对话。\n没有连上游戏时，也可以聊通用玩法。").font(.system(size: 12)).foregroundStyle(palette.secondary).lineSpacing(6)
                                ForEach(["我现在最应该做什么？", "首都下一步造什么？解释一下原因。", "怎么判断第二座城市建在哪里？"], id: \.self) { text in
                                    Button { state.draft = text } label: { HStack { Text(text); Spacer(); Image(systemName: "arrow.up.left") } }.buttonStyle(QuietButton())
                                }
                            }.padding(.vertical, 30).frame(maxWidth: 470, alignment: .leading)
                        }
                        ForEach(state.messages) { msg in
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: msg.role == "user" ? "person.crop.circle" : "sparkles").font(.system(size: 17)).foregroundStyle(msg.role == "user" ? palette.secondary : palette.mint).frame(width: 29, height: 29)
                                VStack(alignment: .leading, spacing: 9) {
                                    HStack {
                                        Text(msg.role == "user" ? "你" : "文明陪练").font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.secondary)
                                        if msg.interrupted { Text("未完成").font(.system(size: 9)).foregroundStyle(palette.gold) }
                                        Spacer()
                                        Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(msg.text, forType: .string) } label: { Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(palette.secondary) }.buttonStyle(.plain).help("复制消息")
                                    }
                                    if msg.text.isEmpty { Text(state.phase).font(.system(size: 12)).foregroundStyle(palette.secondary) }
                                    else { MarkdownText(text: msg.text) }
                                }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(msg.role == "user" ? palette.primary.opacity(0.035) : palette.card, in: RoundedRectangle(cornerRadius: 13))
                            }.id(msg.id)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(.horizontal, 26).padding(.vertical, 16)
                }
                .onChange(of: state.messages.count) { _ in reader.scrollTo("bottom", anchor: .bottom) }
            }
            VStack(spacing: 10) {
                HStack(alignment: .bottom, spacing: 12) {
                    TextField(state.enabled ? "问问老师：为什么现在应该这样做？" : "开启陪练后开始聊天", text: $state.draft, axis: .vertical)
                        .textFieldStyle(.plain).font(.system(size: 13)).lineLimit(2...5).padding(13).background(palette.card, in: RoundedRectangle(cornerRadius: 12)).disabled(!state.enabled)
                        .accessibilityIdentifier("chat-input")
                    if state.generating {
                        Button { state.stopGeneration() } label: { Image(systemName: "stop.fill").frame(width: 20, height: 24) }.buttonStyle(PrimaryButton()).help("停止生成")
                    } else {
                        Button { state.sendDraft() } label: { Image(systemName: "arrow.up").frame(width: 20, height: 24) }.buttonStyle(PrimaryButton()).disabled(!state.enabled || state.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .keyboardShortcut(.return, modifiers: .command).help("发送 ⌘↩").accessibilityIdentifier("send-chat")
                    }
                }
                HStack { Text(state.apiConfigured ? state.modelLabel : "尚未配置 AI 模型"); Spacer(); Text("⌘ ↩ 发送 · 每次发送前刷新局势") }.font(.system(size: 9)).foregroundStyle(palette.secondary)
            }.padding(22).background(palette.sidebar.opacity(0.5))
        }
    }
}

struct SettingsView: View {
    private var palette: ThemePalette { draft.theme.palette }
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var draft = Settings()
    @State private var key = ""
    @State private var localError: String?
    @State private var initialEndpoint = ""
    @State private var initialKey = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) { Text("让你的 AI 成为陪练").font(.system(size: 23, weight: .medium, design: .serif)); Text("Codex 授权 · 自定义 API · 本机模型").font(.system(size: 12)).foregroundStyle(palette.secondary) }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(palette.secondary) }.buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 15) {
                Picker("AI 连接方式", selection: $draft.provider) { ForEach(AIProvider.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented).disabled(state.testing)
                if draft.provider == .api {
                HStack { Text("接口类型").frame(width: 76, alignment: .leading); Picker("接口类型", selection: $draft.style) { ForEach(APIStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.segmented) }
                settingField("API 地址") { TextField("https://api.openai.com/v1", text: $draft.endpoint).accessibilityIdentifier("api-endpoint") }
                settingField("模型名称") { TextField("填写服务商提供的模型 ID", text: $draft.model).accessibilityIdentifier("api-model") }
                settingField("API Key") { SecureField("本机无鉴权模型可留空", text: $key).accessibilityIdentifier("api-key") }
                Text("密钥保存到 macOS 钥匙串。更换 API 地址会清空输入框中的旧密钥。").font(.system(size: 10)).foregroundStyle(palette.secondary)
                } else {
                    Text("使用官方 Codex CLI 的 ChatGPT 登录，无需粘贴 API Key。已登录 CLI 可直接检查授权。请求计入该账号的 Codex 用量。").font(.system(size: 11)).foregroundStyle(palette.secondary)
                    settingField("模型（可选）") { TextField("留空使用 Codex 默认模型", text: $draft.codexModel) }
                    settingField("CLI 路径") { TextField("自动查找；找不到时填写完整路径", text: $draft.codexPath) }
                    HStack {
                        Button("检查授权") { state.codexAuthorization(draft, login: false) }.buttonStyle(QuietButton()).disabled(state.testing)
                        Button("登录 Codex") { state.codexAuthorization(draft, login: true) }.buttonStyle(QuietButton()).disabled(state.testing)
                        Link("打开授权页", destination: URL(string: "https://auth.openai.com/codex/device")!)
                    }
                }
                HStack {
                    Button(state.testing ? "处理中…" : "测试连接") { state.testAPI(draft, key: key) }.buttonStyle(QuietButton()).disabled(state.testing || (draft.provider == .api && draft.model.isEmpty)).accessibilityIdentifier("test-api")
                    if state.testing { ProgressView().controlSize(.small); Button("取消") { state.cancelTest() }.buttonStyle(.plain) }
                    Text("发送一条简短测试，会消耗所选服务的用量。").font(.system(size: 9)).foregroundStyle(palette.secondary)
                }
                if let result = state.testResult { ScrollView { Text(result).font(.system(size: 11)).foregroundStyle(palette.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 90) }
            }.font(.system(size: 12)).padding(20).background(palette.card, in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 15) {
                Text("陪练偏好").font(.system(size: 13, weight: .semibold))
                HStack {
                    Text("界面主题"); Spacer()
                    Picker("界面主题", selection: $draft.theme) { ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 180)
                }
                HStack { Text("学习目标").frame(width: 76, alignment: .leading); TextField("例如：先学会基础运营 / 科技胜利", text: $draft.goal).textFieldStyle(.roundedBorder) }
                HStack { Text("局势刷新"); Spacer(); Picker("局势刷新", selection: $draft.pollSeconds) { Text("每 5 秒").tag(5); Text("每 8 秒").tag(8); Text("每 15 秒").tag(15); Text("每 30 秒").tag(30) }.labelsHidden().frame(width: 140) }
                Toggle("窗口保持在最前面", isOn: $draft.alwaysOnTop)
                Toggle("向 AI 提供首都附近的可见地图", isOn: $draft.includeMap)
                Toggle("在本机保存对话记录", isOn: $draft.rememberChat)
                Text("关闭保存会移除当前对话的本地副本，历史归档仍保留。刷新局势不会自动调用 AI。").font(.system(size: 10)).foregroundStyle(palette.secondary)
            }.font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
            if let localError { Text(localError).font(.system(size: 11)).foregroundStyle(palette.gold) }
            HStack {
                Text(draft.provider == .codex ? "授权由官方 CLI 管理；应用不读取登录令牌。" : "AI 请求直接发往你填写的地址。").font(.system(size: 10)).foregroundStyle(palette.secondary)
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(QuietButton())
                Button("保存设置") {
                    do { try state.saveSettings(draft, key: key); dismiss() } catch { localError = error.localizedDescription }
                }.buttonStyle(PrimaryButton()).disabled(state.testing).accessibilityIdentifier("save-settings")
            }
        }.padding(28).frame(width: 620).background(palette.background).foregroundStyle(palette.primary)
        .environment(\.coachTheme, draft.theme).preferredColorScheme(draft.theme.colorScheme)
        .onAppear {
            draft = state.settings; initialEndpoint = draft.endpoint; state.testResult = nil
            do { key = try Keychain.load(account: draft.keyAccount); initialKey = key } catch { localError = error.localizedDescription }
        }
        .onChange(of: draft.endpoint) { value in key = value == initialEndpoint ? initialKey : ""; state.testResult = nil }
        .onDisappear { state.cancelTest() }
    }
    private func settingField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack { Text(title).frame(width: 76, alignment: .leading); content().textFieldStyle(.roundedBorder) }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let action: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView { let view = NSView(); DispatchQueue.main.async { if let window = view.window { action(window) } }; return view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

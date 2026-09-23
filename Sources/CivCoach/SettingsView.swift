import SwiftUI

private enum SettingsPage: String, CaseIterable {
    case api = "API", appearance = "外观", coaching = "陪练与隐私"
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.coachTheme) private var inheritedTheme
    @State private var draft = Settings()
    @State private var page = SettingsPage.api
    @State private var key = ""
    @State private var localError: String?
    @State private var initialEndpoint = ""
    @State private var initialKey = ""
    @FocusState private var focusedField: FocusField?
    private enum FocusField: Hashable { case endpoint, model, key, goal }
    private var themeStyle: AppThemeStyle {
        AppThemeStyle(accent: draft.theme, appearance: draft.appearance, systemColorScheme: inheritedTheme.systemColorScheme)
    }
    private var previewScheme: ColorScheme { draft.appearance.resolve(system: inheritedTheme.systemColorScheme) }
    private var palette: ThemePalette { themeStyle.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("陪练设置").font(.system(size: 23, weight: .medium, design: .serif))
                    Text("连接 AI，调整外观，选择陪练方式").font(.system(size: 12)).foregroundStyle(palette.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(palette.secondary) }.buttonStyle(.plain)
            }
            CoachChoiceBar(selection: $page, choices: SettingsPage.allCases, title: { $0.rawValue })
                .accessibilityIdentifier("settings-tabs")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch page {
                    case .api: apiPage
                    case .appearance: appearancePage
                    case .coaching: coachingPage
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }.background(palette.card, in: RoundedRectangle(cornerRadius: 14))
            if let localError { Text(localError).font(.system(size: 11)).foregroundStyle(palette.gold) }
            HStack {
                Text("保存将应用所有分页的修改。").font(.system(size: 10)).foregroundStyle(palette.secondary)
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(QuietButton())
                Button("保存设置") {
                    do { try state.saveSettings(draft, key: key); dismiss() }
                    catch { localError = error.localizedDescription; page = .api }
                }.buttonStyle(PrimaryButton()).disabled(state.testing).accessibilityIdentifier("save-settings")
            }
        }.padding(28).frame(width: 620, height: 570).background(palette.background).foregroundStyle(palette.primary)
        .environment(\.coachTheme, themeStyle).preferredColorScheme(draft.appearance.preferredColorScheme)
        .onAppear {
            draft = state.settings; initialEndpoint = draft.endpoint; state.clearTestResult()
            do { key = try Keychain.load(account: draft.keyAccount); initialKey = key }
            catch { localError = error.localizedDescription }
        }
        .onChange(of: draft.endpoint) { value in key = value == initialEndpoint ? initialKey : ""; state.clearTestResult() }
        .onChange(of: draft.model) { _ in state.clearTestResult() }
        .onChange(of: draft.style) { _ in state.clearTestResult() }
        .onChange(of: key) { _ in state.clearTestResult() }
        .onDisappear { state.cancelTest() }
    }
    private var apiPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("自定义 API").font(.system(size: 15, weight: .semibold))
            Text("支持 OpenAI 兼容接口与本机模型。").foregroundStyle(palette.secondary)
            HStack(spacing: 12) {
                Text("接口类型").frame(width: 76, alignment: .leading)
                CoachChoiceBar(selection: $draft.style, choices: APIStyle.allCases, title: { $0.rawValue })
            }
            field("API 地址", focused: focusedField == .endpoint) {
                TextField("https://api.openai.com/v1", text: $draft.endpoint)
                    .focused($focusedField, equals: .endpoint).accessibilityIdentifier("api-endpoint")
            }
            field("模型名称", focused: focusedField == .model) {
                TextField("填写服务商提供的模型 ID", text: $draft.model)
                    .focused($focusedField, equals: .model).accessibilityIdentifier("api-model")
            }
            field("API Key", focused: focusedField == .key) {
                SecureField("本机无鉴权模型可留空", text: $key)
                    .focused($focusedField, equals: .key).accessibilityIdentifier("api-key")
            }
            Text("密钥保存到 macOS 钥匙串。更换地址会清空密钥输入，改回原地址会恢复。请求直接发送到你填写的地址。").font(.system(size: 10)).foregroundStyle(palette.secondary)
            HStack(spacing: 10) {
                Button(state.testing ? "测试中…" : "测试连接") { state.testAPI(draft, key: key) }.buttonStyle(QuietButton()).disabled(state.testing || draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("test-api")
                if state.testing { ProgressView().controlSize(.small); Button("停止测试") { state.cancelTest() }.buttonStyle(.plain) }
                if let result = state.testResult {
                    Image(systemName: result.icon)
                        .foregroundStyle(testResultColor(result))
                    Text(result.message)
                        .foregroundStyle(testResultColor(result))
                        .lineLimit(2)
                        .help(result.message)
                        .accessibilityIdentifier("api-test-result")
                }
            }
            Text("测试会发送简短请求，可能产生少量费用。").font(.system(size: 10)).foregroundStyle(palette.secondary)
        }.font(.system(size: 12))
    }
    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("强调色").font(.system(size: 15, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button { draft.theme = theme } label: {
                        let swatch = theme.palette(for: previewScheme)
                        HStack {
                            Circle().fill(swatch.mint).frame(width: 18, height: 18)
                            Text(theme.title).foregroundStyle(swatch.primary)
                            Spacer()
                            if draft.theme == theme { Image(systemName: "checkmark.circle.fill").foregroundStyle(swatch.mint) }
                        }.padding(14).background(swatch.background, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(draft.theme == theme ? palette.mint : palette.line, lineWidth: 1.5))
                    }.buttonStyle(.plain).accessibilityLabel(theme.title).accessibilityValue(draft.theme == theme ? "已选择" : "未选择")
                }
            }
            Text("外观").font(.system(size: 15, weight: .semibold))
            CoachChoiceBar(selection: $draft.appearance, choices: AppAppearance.allCases, title: { $0.title })
                .accessibilityIdentifier("appearance-mode")
            Text("强调色只改变界面点缀色；深浅外观可独立选择，也可跟随 macOS 系统设置。保存后同步主窗口与快捷小窗。")
                .font(.system(size: 11)).foregroundStyle(palette.secondary)
            Text("主窗口右上角图钉可单独固定主窗口；快捷卡片也有自己的图钉。虚线矩形图标进入透明游戏叠加层并自动置顶。透明层只保留建议与小图标，实心矩形图标退出透明。拖动顶部移动、拖动四边或四角缩放，两种模式分别记住尺寸。").font(.system(size: 11)).foregroundStyle(palette.secondary)
        }.font(.system(size: 12))
    }
    private var coachingPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("陪练与隐私").font(.system(size: 15, weight: .semibold))
            field("学习目标", focused: focusedField == .goal) {
                TextField("例如：基础运营 / 科技胜利", text: $draft.goal)
                    .focused($focusedField, equals: .goal)
            }
            Text("这段文字会附加到 AI 的教师提示词中，不是整套模板。可写“先学基础运营”“科技胜利”“文化胜利”或“征服胜利”，也可以自由描述。").font(.system(size: 11)).foregroundStyle(palette.secondary)
            HStack(spacing: 12) {
                Text("局势刷新").frame(width: 76, alignment: .leading)
                CoachChoiceBar(selection: $draft.pollSeconds, choices: [5, 8, 15, 30], title: { "每 \($0) 秒" })
            }
            Toggle("读取所有城市和单位附近的可见地图", isOn: $draft.includeMap)
            Text("周围 3 格、只含当前视野，去重后最多 4000 地块；发送 AI 时最多 240 个地块细节和 400 条单位记录，并标注抽样。不读取迷雾。").font(.system(size: 11)).foregroundStyle(palette.secondary)
            Toggle("在本机保存对话记录", isOn: $draft.rememberChat)
            Text("关闭保存会移除当前对话的本地副本，历史归档仍保留。游戏读取仅在本机进行，刷新不会自动调用 AI。只有点建议或发送聊天时，才将相关数据发送到 API。").font(.system(size: 11)).foregroundStyle(palette.secondary).lineSpacing(5)
        }.font(.system(size: 12)).toggleStyle(.switch).tint(palette.mint).controlSize(.small)
    }
    private func field<Content: View>(_ title: String, focused: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 76, alignment: .leading)
            content().modifier(CoachInputStyle(focused: focused))
        }
    }
    private func testResultColor(_ result: APITestResult) -> Color {
        switch result {
        case .success: return palette.mint
        case .cancelled: return palette.secondary
        case .failure: return palette.gold
        }
    }
}

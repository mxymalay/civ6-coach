import SwiftUI

private enum SettingsPage: String, CaseIterable {
    case api = "API", appearance = "外观", overlay = "透明小窗", coaching = "陪练与隐私"
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    @Environment(\.dismiss) var dismiss
    @Environment(\.coachTheme) private var inheritedTheme
    @State private var draft = Settings()
    @State private var page = SettingsPage.api
    @State private var keys: [UUID: String] = [:]
    @State private var localError: String?
    @State private var initialEndpoints: [UUID: String] = [:]
    @State private var initialKeys: [UUID: String] = [:]
    @State private var editingProfileName = false
    @State private var customGoal = false
    @State private var customGoalText = ""
    @FocusState private var focusedField: FocusField?
    private enum FocusField: Hashable { case name, endpoint, model, key, goal }
    private var key: String { keys[draft.selectedAPIID] ?? "" }
    private var themeStyle: AppThemeStyle {
        AppThemeStyle(accent: draft.theme, appearance: draft.appearance, systemColorScheme: inheritedTheme.systemColorScheme)
    }
    private var previewScheme: ColorScheme { draft.appearance.resolve(system: inheritedTheme.systemColorScheme) }
    private var palette: ThemePalette { themeStyle.palette }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("陪练设置").font(.system(size: 23, weight: .medium, design: .serif))
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
                    case .overlay: overlayPage
                    case .coaching: coachingPage
                    }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            }.background(palette.card, in: RoundedRectangle(cornerRadius: 14))
            if let localError { Text(localError).font(.system(size: 11)).foregroundStyle(palette.gold) }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.buttonStyle(QuietButton())
                Button("保存设置") {
                    do { try state.saveSettings(draft, keys: keys); dismiss() }
                    catch { localError = error.localizedDescription; page = .api }
                }.buttonStyle(PrimaryButton())
                    .disabled(state.testing || state.generating || draft.apiProfiles.contains { keys[$0.id] == nil })
                    .accessibilityIdentifier("save-settings")
            }
        }.padding(28).frame(width: 620, height: 570).background(palette.background).foregroundStyle(palette.primary)
        .environment(\.coachTheme, themeStyle).preferredColorScheme(draft.appearance.preferredColorScheme)
        .onAppear {
            draft = state.settings; state.clearTestResult()
            for profile in draft.apiProfiles {
                initialEndpoints[profile.id] = profile.endpoint
                do { keys[profile.id] = try Keychain.load(account: profile.keyAccount) }
                catch { localError = error.localizedDescription }
            }
            initialKeys = keys
            customGoal = !LearningGoalPreset.allCases.contains { $0.prompt == draft.goal }
            customGoalText = customGoal ? draft.goal : ""
        }
        .onChange(of: draft.model) { _ in state.clearTestResult() }
        .onChange(of: draft.style) { _ in state.clearTestResult() }
        .onChange(of: key) { _ in state.clearTestResult() }
        .onDisappear { state.cancelTest() }
    }
    private var apiPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                APIProfileMenu(profiles: draft.apiProfiles, selectedID: draft.selectedAPIID) { id in
                    draft.selectAPIProfile(id); editingProfileName = false
                    focusedField = nil; state.clearTestResult()
                }
                Button { addProfile() } label: { Image(systemName: "plus").frame(width: 22, height: 22) }
                    .buttonStyle(CompactActionButton()).help("新增 API 配置").accessibilityLabel("新增 API 配置")
                Button { editingProfileName.toggle(); focusedField = editingProfileName ? .name : nil } label: {
                    Image(systemName: "pencil").frame(width: 22, height: 22)
                }.buttonStyle(CompactActionButton()).help("重命名配置").accessibilityLabel("重命名配置")
                Button { removeProfile() } label: { Image(systemName: "trash").frame(width: 22, height: 22) }
                    .buttonStyle(CompactActionButton()).help("删除当前配置，保存后生效").accessibilityLabel("删除当前 API 配置")
            }
            if editingProfileName {
                field("配置名称", focused: focusedField == .name) {
                    TextField("给这套 API 起个名字", text: $draft.profileName)
                        .focused($focusedField, equals: .name)
                        .onSubmit { editingProfileName = false }
                }
            }
            HStack(spacing: 12) {
                Text("接口类型").frame(width: 76, alignment: .leading)
                CoachChoiceBar(selection: $draft.style, choices: APIStyle.allCases, title: { $0.rawValue })
            }
            field("API 地址", focused: focusedField == .endpoint) {
                TextField("https://api.openai.com/v1", text: Binding(get: { draft.endpoint }, set: { value in
                    draft.endpoint = value
                    keys[draft.selectedAPIID] = value == initialEndpoints[draft.selectedAPIID] ? initialKeys[draft.selectedAPIID] ?? "" : ""
                    state.clearTestResult()
                }))
                    .focused($focusedField, equals: .endpoint).accessibilityIdentifier("api-endpoint")
            }
            field("模型名称", focused: focusedField == .model) {
                TextField("填写服务商提供的模型 ID", text: $draft.model)
                    .focused($focusedField, equals: .model).accessibilityIdentifier("api-model")
            }
            field("API Key", focused: focusedField == .key) {
                SecureField("本机无鉴权模型可留空", text: Binding(get: { key }, set: { keys[draft.selectedAPIID] = $0 }))
                    .focused($focusedField, equals: .key).accessibilityIdentifier("api-key")
            }
            Text("密钥存于本机钥匙串；更换地址会清空密钥。").font(.system(size: 10)).foregroundStyle(palette.secondary)
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
        }.font(.system(size: 12))
    }
    private var coachingPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("陪练与隐私").font(.system(size: 15, weight: .semibold))
            Text("学习目标").font(.system(size: 12, weight: .medium))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(LearningGoalPreset.allCases, id: \.self) { preset in
                    goalChoice(preset.rawValue, icon: preset.icon, selected: !customGoal && draft.goal == preset.prompt) {
                        if customGoal { customGoalText = draft.goal }
                        customGoal = false; draft.goal = preset.prompt; focusedField = nil
                    }
                }
                goalChoice("自定义", icon: "pencil", selected: customGoal) {
                    if !customGoal { draft.goal = customGoalText }
                    customGoal = true; focusedField = .goal
                }
            }
            if customGoal {
                TextField("想重点学什么？", text: $draft.goal)
                    .focused($focusedField, equals: .goal)
                    .modifier(CoachInputStyle(focused: focusedField == .goal))
            }
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
    private var overlayPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("操作引导").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("即时生效").font(.system(size: 10)).foregroundStyle(palette.secondary)
            }
            Toggle("首次进入时显示引导", isOn: overlayBinding(\.guideEnabled))
                .toggleStyle(.switch).tint(palette.mint).controlSize(.small)
            Button { dismiss(); quickPanel.showGuide() } label: {
                Label("重新引导", systemImage: "questionmark.circle")
            }.buttonStyle(QuietButton())
            Divider()
            Text("文字样式").font(.system(size: 15, weight: .semibold))
            Text("字号").font(.system(size: 12))
            CoachChoiceBar(selection: overlayBinding(\.fontSize), choices: [10, 12, 14, 16, 18, 22, 26], title: { String($0) })
            Text("字体").font(.system(size: 12))
            CoachChoiceBar(selection: overlayBinding(\.font), choices: OverlayFont.allCases, title: { $0.rawValue })
            Text("颜色").font(.system(size: 12))
            CoachChoiceBar(selection: overlayBinding(\.color), choices: OverlayColor.allCases, title: { $0.rawValue })
            Text("阴影").font(.system(size: 12))
            CoachChoiceBar(selection: overlayBinding(\.shadow), choices: OverlayShadow.allCases, title: { $0.rawValue })
        }
    }
    private func overlayBinding<Value>(_ path: WritableKeyPath<OverlayOptions, Value>) -> Binding<Value> {
        Binding(get: { quickPanel.preferences.overlay[keyPath: path] }, set: { value in
            var options = quickPanel.preferences.overlay
            options[keyPath: path] = value
            quickPanel.updateOverlayOptions(options)
        })
    }
    private func addProfile() {
        let id = draft.addAPIProfile()
        keys[id] = ""; initialKeys[id] = ""; initialEndpoints[id] = draft.endpoint
        editingProfileName = true; focusedField = .name; state.clearTestResult()
    }
    private func removeProfile() {
        let oldIDs = Set(draft.apiProfiles.map(\.id))
        keys.removeValue(forKey: draft.selectedAPIID)
        draft.removeAPIProfile(draft.selectedAPIID)
        if !oldIDs.contains(draft.selectedAPIID) {
            keys[draft.selectedAPIID] = ""; initialKeys[draft.selectedAPIID] = ""
            initialEndpoints[draft.selectedAPIID] = draft.endpoint
        }
        editingProfileName = false; focusedField = nil; state.clearTestResult()
    }
    private func goalChoice(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) { Image(systemName: icon); Text(title) }
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .foregroundStyle(selected ? palette.mint : palette.secondary)
                .background(selected ? palette.mint.opacity(0.10) : palette.sidebar, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? palette.mint.opacity(0.6) : palette.line))
        }.buttonStyle(.plain).accessibilityValue(selected ? "已选择" : "未选择")
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

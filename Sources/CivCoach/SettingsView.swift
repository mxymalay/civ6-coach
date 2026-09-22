import SwiftUI

private enum SettingsPage: String, CaseIterable {
    case api = "API", appearance = "外观", coaching = "陪练与隐私"
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var draft = Settings()
    @State private var page = SettingsPage.api
    @State private var key = ""
    @State private var localError: String?
    @State private var initialEndpoint = ""
    @State private var initialKey = ""
    private var palette: ThemePalette { draft.theme.palette }

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
            Picker("设置分类", selection: $page) {
                ForEach(SettingsPage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).accessibilityIdentifier("settings-tabs")
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
        .environment(\.coachTheme, draft.theme).preferredColorScheme(draft.theme.colorScheme)
        .onAppear {
            draft = state.settings; initialEndpoint = draft.endpoint; state.testResult = nil
            do { key = try Keychain.load(account: draft.keyAccount); initialKey = key }
            catch { localError = error.localizedDescription }
        }
        .onChange(of: draft.endpoint) { value in key = value == initialEndpoint ? initialKey : ""; state.testResult = nil }
        .onDisappear { state.cancelTest() }
    }
    private var apiPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("自定义 API").font(.system(size: 15, weight: .semibold))
            Text("支持 OpenAI 兼容接口与本机模型。").foregroundStyle(palette.secondary)
            HStack { Text("接口类型").frame(width: 76, alignment: .leading); Picker("接口类型", selection: $draft.style) { ForEach(APIStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden().pickerStyle(.segmented) }
            field("API 地址") { TextField("https://api.openai.com/v1", text: $draft.endpoint).accessibilityIdentifier("api-endpoint") }
            field("模型名称") { TextField("填写服务商提供的模型 ID", text: $draft.model).accessibilityIdentifier("api-model") }
            field("API Key") { SecureField("本机无鉴权模型可留空", text: $key).accessibilityIdentifier("api-key") }
            Text("密钥保存到 macOS 钥匙串。更换地址会清空密钥输入，改回原地址会恢复。请求直接发送到你填写的地址。").font(.system(size: 10)).foregroundStyle(palette.secondary)
            HStack {
                Button(state.testing ? "测试中…" : "测试连接") { state.testAPI(draft, key: key) }.buttonStyle(QuietButton()).disabled(state.testing || draft.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("test-api")
                if state.testing { ProgressView().controlSize(.small); Button("停止测试") { state.cancelTest() }.buttonStyle(.plain) }
            }
            Text("测试会发送简短请求，可能产生少量费用。").font(.system(size: 10)).foregroundStyle(palette.secondary)
            if let result = state.testResult { Text(result).foregroundStyle(palette.secondary).textSelection(.enabled) }
        }.font(.system(size: 12))
    }
    private var appearancePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("界面主题").font(.system(size: 15, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button { draft.theme = theme } label: {
                        HStack {
                            Circle().fill(theme.palette.mint).frame(width: 18, height: 18)
                            Text(theme.title).foregroundStyle(theme.palette.primary)
                            Spacer()
                            if draft.theme == theme { Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.palette.mint) }
                        }.padding(14).background(theme.palette.background, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(draft.theme == theme ? palette.mint : palette.line, lineWidth: 1.5))
                    }.buttonStyle(.plain).accessibilityLabel(theme.title).accessibilityValue(draft.theme == theme ? "已选择" : "未选择")
                }
            }
            Text("当前设置页即时预览；保存后同步主窗口与快捷小窗。").font(.system(size: 11)).foregroundStyle(palette.secondary)
            Toggle("主窗口保持在最前面", isOn: $draft.alwaysOnTop).toggleStyle(.switch).controlSize(.small)
            Text("快捷小窗固定后变成透明游戏叠加层，只保留文字与空心按钮；移入顶部显示控制，拖动顶部移动，拖动边缘缩放。取消固定恢复完整小窗。").font(.system(size: 11)).foregroundStyle(palette.secondary)
        }.font(.system(size: 12))
    }
    private var coachingPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("陪练与隐私").font(.system(size: 15, weight: .semibold))
            field("学习目标") { TextField("例如：基础运营 / 科技胜利", text: $draft.goal) }
            HStack { Text("局势刷新"); Spacer(); Picker("局势刷新", selection: $draft.pollSeconds) { Text("每 5 秒").tag(5); Text("每 8 秒").tag(8); Text("每 15 秒").tag(15); Text("每 30 秒").tag(30) }.labelsHidden().frame(width: 140) }
            Toggle("读取所有城市和单位附近的可见地图", isOn: $draft.includeMap)
            Text("周围 3 格、只含当前视野，去重后最多 4000 地块；发送 AI 时最多 240 个地块细节和 400 条单位记录，并标注抽样。不读取迷雾。").font(.system(size: 11)).foregroundStyle(palette.secondary)
            Toggle("在本机保存对话记录", isOn: $draft.rememberChat)
            Text("关闭保存会移除当前对话的本地副本，历史归档仍保留。游戏读取仅在本机进行，刷新不会自动调用 AI。只有点建议或发送聊天时，才将相关数据发送到 API。").font(.system(size: 11)).foregroundStyle(palette.secondary).lineSpacing(5)
        }.font(.system(size: 12)).toggleStyle(.switch).controlSize(.small)
    }
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack { Text(title).frame(width: 76, alignment: .leading); content().textFieldStyle(.roundedBorder) }
    }
}

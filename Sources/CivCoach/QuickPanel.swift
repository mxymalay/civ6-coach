import AppKit
import SwiftUI

struct PanelPresentation {
    let transparent: Bool
    var hasShadow: Bool { !transparent }
    var minimumWidth: Double { transparent ? 240 : 320 }
    var minimumHeight: Double { transparent ? 120 : 280 }
    static func keepingOnScreen(_ frame: NSRect, visible: NSRect) -> NSRect {
        var result = frame
        result.origin.x = max(visible.minX, min(result.minX, visible.maxX - result.width))
        result.origin.y = max(visible.minY, min(result.minY, visible.maxY - result.height))
        return result
    }
}

struct PanelPreferences: Codable {
    var pinned = false
    var transparent = false
    private var normalWidth = 380.0
    private var normalHeight = 400.0
    private var overlayWidth = 320.0
    private var overlayHeight = 220.0
    var width: Double { transparent ? overlayWidth : normalWidth }
    var height: Double { transparent ? overlayHeight : normalHeight }
    var dismissesOnOutsideClick: Bool { !pinned && !transparent }
    var presentation: PanelPresentation { PanelPresentation(transparent: transparent) }
    init() {}
    enum CodingKeys: String, CodingKey { case pinned, transparent, normalWidth, normalHeight, overlayWidth, overlayHeight, width, height }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        let mode = try c.decodeIfPresent(Bool.self, forKey: .transparent)
        transparent = true
        resize(width: try c.decodeIfPresent(Double.self, forKey: .overlayWidth) ?? 320,
               height: try c.decodeIfPresent(Double.self, forKey: .overlayHeight) ?? 220)
        transparent = false
        resize(width: try c.decodeIfPresent(Double.self, forKey: .normalWidth) ?? 380,
               height: try c.decodeIfPresent(Double.self, forKey: .normalHeight) ?? 400)
        transparent = mode ?? pinned
        if mode == nil {
            pinned = false
            resize(width: try c.decodeIfPresent(Double.self, forKey: .width) ?? width,
                   height: try c.decodeIfPresent(Double.self, forKey: .height) ?? height)
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(pinned, forKey: .pinned)
        try c.encode(transparent, forKey: .transparent)
        try c.encode(normalWidth, forKey: .normalWidth)
        try c.encode(normalHeight, forKey: .normalHeight)
        try c.encode(overlayWidth, forKey: .overlayWidth)
        try c.encode(overlayHeight, forKey: .overlayHeight)
    }
    mutating func resize(width: Double, height: Double) {
        let w = width.isFinite ? min(1000, max(presentation.minimumWidth, width)) : 380
        let h = height.isFinite ? min(1000, max(presentation.minimumHeight, height)) : 400
        if transparent { overlayWidth = w; overlayHeight = h }
        else { normalWidth = w; normalHeight = h }
    }
}

enum PanelInteraction {
    static func isMoveArea(_ point: NSPoint, bounds: NSRect, transparent: Bool) -> Bool {
        guard bounds.contains(point), PanelResizeGeometry.edges(at: point, in: bounds).isEmpty else { return false }
        let reservedControls: CGFloat = transparent ? 66 : 112
        return point.y >= bounds.maxY - 40 && point.x < bounds.maxX - reservedControls
    }
}

private final class CoachPanel: NSPanel {
    var transparentMode = false
    var overlayMenu: (() -> NSMenu)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func sendEvent(_ event: NSEvent) {
        if transparentMode,
           event.type == .rightMouseDown || (event.type == .leftMouseDown && event.modifierFlags.contains(.control)),
           let contentView, let menu = overlayMenu?() {
            NSMenu.popUpContextMenu(menu, with: event, for: contentView)
            return
        }
        if event.type == .leftMouseDown,
           PanelInteraction.isMoveArea(event.locationInWindow,
               bounds: NSRect(origin: .zero, size: frame.size), transparent: transparentMode) {
            performDrag(with: event)
            return
        }
        super.sendEvent(event)
    }
}

@MainActor final class QuickPanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var preferences: PanelPreferences
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var outsideMonitor: Any?
    private var localMonitor: Any?
    private var openMain: (() -> Void)?
    private weak var state: AppState?
    private var changingPresentation = false

    override init() {
        preferences = AppState.preferences.data(forKey: "coach.panel.v1")
            .flatMap { try? JSONDecoder().decode(PanelPreferences.self, from: $0) } ?? PanelPreferences()
        super.init()
    }
    func install(state: AppState, openMain: @escaping () -> Void) {
        self.openMain = openMain
        guard statusItem == nil else { return }
        self.state = state
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "文"
        item.button?.font = .systemFont(ofSize: 16, weight: .semibold)
        item.button?.toolTip = "文明 VI 陪练"
        item.button?.setAccessibilityLabel("文明 VI 陪练快捷窗口")
        item.button?.target = self; item.button?.action = #selector(togglePanel)
        statusItem = item

        let window = CoachPanel(contentRect: NSRect(x: 0, y: 0, width: preferences.width, height: preferences.height),
                                styleMask: [.titled, .resizable, .closable, .nonactivatingPanel, .fullSizeContentView],
                                backing: .buffered, defer: false)
        window.title = "文明 VI 快捷陪练"
        window.identifier = NSUserInterfaceItemIdentifier("coach-quick-panel")
        window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { window.standardWindowButton(button)?.isHidden = true }
        window.isMovableByWindowBackground = false
        window.overlayMenu = { [weak self] in self?.makeOverlayMenu() ?? NSMenu() }
        window.hidesOnDeactivate = false; window.isReleasedWhenClosed = false
        window.isFloatingPanel = true; window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentMaxSize = NSSize(width: 1000, height: 1000)
        window.contentView = NSHostingView(rootView: QuickPanelRoot().environmentObject(state).environmentObject(self))
        window.delegate = self
        panel = window
        applyPresentation()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.dismissOutside() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window !== self.panel, event.window !== self.statusItem?.button?.window { self.dismissOutside() }
            return event
        }
    }
    @objc func togglePanel() {
        guard let panel else { return }
        if panel.isVisible { panel.orderOut(nil); return }
        if let buttonWindow = statusItem?.button?.window {
            let screen = buttonWindow.screen ?? NSScreen.main
            let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width = min(preferences.width, visible.width)
            let height = min(preferences.height, visible.height)
            let x = min(max(visible.minX, buttonWindow.frame.maxX - width), visible.maxX - width)
            let y = max(visible.minY, visible.maxY - height - 6)
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: false)
        }
        panel.makeKeyAndOrderFront(nil)
    }
    func togglePin() {
        preferences.pinned.toggle()
        savePreferences()
    }
    func toggleOverlay() {
        preferences.transparent.toggle()
        applyPresentation()
        savePreferences()
    }
    private func applyPresentation() {
        guard let panel else { return }
        changingPresentation = true
        defer { changingPresentation = false }
        let appearance = preferences.presentation
        (panel as? CoachPanel)?.transparentMode = appearance.transparent
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let visible = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        // Both layouts own their compact headers; reserve no native title-bar space.
        panel.styleMask = [.borderless, .resizable, .nonactivatingPanel]
        panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { panel.standardWindowButton(button)?.isHidden = true }
        panel.isOpaque = !appearance.transparent
        panel.backgroundColor = appearance.transparent ? .clear : .windowBackgroundColor
        panel.hasShadow = appearance.hasShadow
        panel.level = .floating
        panel.contentMinSize = NSSize(width: appearance.minimumWidth, height: appearance.minimumHeight)
        let proposed = NSRect(x: topLeft.x, y: topLeft.y - preferences.height, width: preferences.width, height: preferences.height)
        panel.setFrame(visible.map { PanelPresentation.keepingOnScreen(proposed, visible: $0) } ?? proposed, display: true)
        panel.invalidateShadow()
    }
    func closePanel() { panel?.orderOut(nil) }
    var overlayActionTitle: String {
        guard let state else { return "生成建议" }
        if state.generating { return "停止生成" }
        if !state.enabled { return "开启陪练" }
        if !state.apiConfigured { return "配置 AI" }
        return "生成建议"
    }
    @objc func performOverlayAction() {
        guard let state else { return }
        if state.generating { state.stopGeneration() }
        else if !state.enabled { state.setEnabled(true) }
        else if !state.apiConfigured { showMain(settings: true) }
        else { state.askAdvice() }
    }
    @objc private func exitOverlay() {
        if preferences.transparent { toggleOverlay() }
    }
    func makeOverlayMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let generate = NSMenuItem(title: state?.generating == true ? "停止生成" : "生成建议",
                                  action: #selector(performOverlayAction), keyEquivalent: "")
        generate.target = self
        generate.isEnabled = state?.generating == true || (state?.enabled == true && state?.apiConfigured == true)
        generate.toolTip = generate.isEnabled ? nil : "请先开启陪练并配置 AI"
        menu.addItem(generate)
        menu.addItem(.separator())
        let exit = NSMenuItem(title: "退出透明", action: #selector(exitOverlay), keyEquivalent: "")
        exit.target = self
        menu.addItem(exit)
        return menu
    }
    func showMain(settings: Bool = false, chat: Bool = false) {
        if chat { state?.selectedTab = "和老师聊聊" }
        openMain?(); NSApp.activate(ignoringOtherApps: true)
        if settings { state?.settingsOpen = true }
        dismissOutside()
    }
    private func dismissOutside() {
        if preferences.dismissesOnOutsideClick { panel?.orderOut(nil) }
    }
    func windowDidResignKey(_ notification: Notification) { dismissOutside() }
    func windowDidResize(_ notification: Notification) {
        guard let panel, !changingPresentation else { return }
        preferences.resize(width: panel.frame.width, height: panel.frame.height)
        savePreferences()
    }
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) { AppState.preferences.set(data, forKey: "coach.panel.v1") }
    }
}

private struct QuickPanelRoot: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var quickPanel: QuickPanelController
    var body: some View {
        Group {
            if quickPanel.preferences.transparent { GameOverlayView() }
            else { MenuContent() }
        }.environment(\.coachTheme, state.settings.theme)
         .preferredColorScheme(quickPanel.preferences.transparent ? .dark : state.settings.theme.colorScheme)
         .overlay { PanelResizeBorder() }
    }
}

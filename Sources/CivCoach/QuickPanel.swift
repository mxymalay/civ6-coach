import AppKit
import SwiftUI

struct PanelPresentation {
    let transparent: Bool
    var hasShadow: Bool { !transparent }
    var minimumWidth: Double { transparent ? 300 : 360 }
    var minimumHeight: Double { transparent ? 200 : 420 }
    static func keepingOnScreen(_ frame: NSRect, visible: NSRect) -> NSRect {
        var result = frame
        result.origin.x = max(visible.minX, min(result.minX, visible.maxX - result.width))
        result.origin.y = max(visible.minY, min(result.minY, visible.maxY - result.height))
        return result
    }
}

struct PanelPreferences: Codable {
    var pinned = false
    private(set) var width = 380.0
    private(set) var height = 520.0
    var dismissesOnOutsideClick: Bool { !pinned }
    var presentation: PanelPresentation { PanelPresentation(transparent: pinned) }
    init() {}
    enum CodingKeys: String, CodingKey { case pinned, width, height }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        resize(width: try c.decodeIfPresent(Double.self, forKey: .width) ?? 380,
               height: try c.decodeIfPresent(Double.self, forKey: .height) ?? 520)
    }
    mutating func resize(width: Double, height: Double) {
        self.width = width.isFinite ? min(1000, max(presentation.minimumWidth, width)) : 380
        self.height = height.isFinite ? min(1000, max(presentation.minimumHeight, height)) : 520
    }
}

private final class CoachPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
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
        window.isMovableByWindowBackground = true
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
        preferences.resize(width: preferences.width, height: preferences.height)
        applyPresentation()
        savePreferences()
    }
    private func applyPresentation() {
        guard let panel else { return }
        changingPresentation = true
        defer { changingPresentation = false }
        let appearance = preferences.presentation
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        let visible = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        panel.styleMask = appearance.transparent
            ? [.borderless, .resizable, .nonactivatingPanel]
            : [.titled, .resizable, .closable, .nonactivatingPanel, .fullSizeContentView]
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
            if quickPanel.preferences.pinned { GameOverlayView() }
            else { MenuContent() }
        }.environment(\.coachTheme, state.settings.theme)
         .preferredColorScheme(quickPanel.preferences.pinned ? .dark : state.settings.theme.colorScheme)
    }
}

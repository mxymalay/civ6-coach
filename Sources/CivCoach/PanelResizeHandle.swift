import AppKit
import SwiftUI

/// A visible 30-point grip instead of the very narrow native transparent edge.
struct PanelResizeHandle: NSViewRepresentable {
    final class ResizeView: NSView {
        private var startMouse = NSPoint.zero
        private var startFrame = NSRect.zero
        override var mouseDownCanMoveWindow: Bool { false }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            startMouse = NSEvent.mouseLocation; startFrame = window.frame
        }
        override func mouseDragged(with event: NSEvent) {
            guard let window else { return }
            let mouse = NSEvent.mouseLocation
            let target = PanelResizeGeometry.frame(start: startFrame,
                delta: NSSize(width: mouse.x - startMouse.x, height: mouse.y - startMouse.y),
                minimum: window.minSize, maximum: window.maxSize,
                visible: window.screen?.visibleFrame)
            window.setFrame(target, display: true)
        }
        override func accessibilityLabel() -> String? { "调整小窗大小" }
    }
    func makeNSView(context: Context) -> NSView { ResizeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

enum PanelResizeGeometry {
    static func frame(start: NSRect, delta: NSSize, minimum: NSSize, maximum: NSSize, visible: NSRect?) -> NSRect {
        let maxWidth = min(maximum.width, visible.map { max(minimum.width, $0.maxX - start.minX) } ?? maximum.width)
        let maxHeight = min(maximum.height, visible.map { max(minimum.height, start.maxY - $0.minY) } ?? maximum.height)
        let width = min(maxWidth, max(minimum.width, start.width + delta.width))
        let height = min(maxHeight, max(minimum.height, start.height - delta.height))
        return NSRect(x: start.minX, y: start.maxY - height, width: width, height: height)
    }
}

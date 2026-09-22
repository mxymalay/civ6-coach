import AppKit
import SwiftUI

/// Invisible edge-only hit zones. The center passes clicks to the SwiftUI content.
struct PanelResizeBorder: NSViewRepresentable {
    final class ResizeView: NSView {
        private var startMouse = NSPoint.zero
        private var startFrame = NSRect.zero
        private var edges: PanelEdges = []
        override var mouseDownCanMoveWindow: Bool { false }
        override func draw(_ dirtyRect: NSRect) {
            // Give the native transparent window an event surface even between dashes.
            NSColor.white.withAlphaComponent(0.01).setFill()
            NSRect(x: 0, y: 0, width: 8, height: bounds.height).fill()
            NSRect(x: bounds.width - 8, y: 0, width: 8, height: bounds.height).fill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 8).fill()
            NSRect(x: 0, y: bounds.height - 8, width: bounds.width, height: 8).fill()
            for x in [CGFloat(0), bounds.width - 14] {
                for y in [CGFloat(0), bounds.height - 14] {
                    NSRect(x: x, y: y, width: 14, height: 14).fill()
                }
            }
        }
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from: superview)
            return bounds.contains(local) && !PanelResizeGeometry.edges(at: local, in: bounds).isEmpty ? self : nil
        }
        override func resetCursorRects() {
            for rect in [
                NSRect(x: 0, y: 0, width: 8, height: bounds.height),
                NSRect(x: bounds.width - 8, y: 0, width: 8, height: bounds.height)
            ] { addCursorRect(rect, cursor: .resizeLeftRight) }
            for rect in [
                NSRect(x: 0, y: 0, width: bounds.width, height: 8),
                NSRect(x: 0, y: bounds.height - 8, width: bounds.width, height: 8)
            ] { addCursorRect(rect, cursor: .resizeUpDown) }
            for x in [CGFloat(0), bounds.width - 14] {
                for y in [CGFloat(0), bounds.height - 14] {
                    addCursorRect(NSRect(x: x, y: y, width: 14, height: 14), cursor: .crosshair)
                }
            }
        }
        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            edges = PanelResizeGeometry.edges(at: convert(event.locationInWindow, from: nil), in: bounds)
            startMouse = NSEvent.mouseLocation
            startFrame = window.frame
        }
        override func mouseDragged(with event: NSEvent) {
            guard let window, !edges.isEmpty else { return }
            let mouse = NSEvent.mouseLocation
            window.setFrame(PanelResizeGeometry.frame(start: startFrame,
                delta: NSSize(width: mouse.x - startMouse.x, height: mouse.y - startMouse.y),
                minimum: window.minSize, maximum: window.maxSize,
                visible: window.screen?.visibleFrame, edges: edges), display: true)
        }
    }
    func makeNSView(context: Context) -> NSView { ResizeView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct PanelEdges: OptionSet {
    let rawValue: Int
    static let left = Self(rawValue: 1)
    static let right = Self(rawValue: 2)
    static let top = Self(rawValue: 4)
    static let bottom = Self(rawValue: 8)
}

enum PanelResizeGeometry {
    static func edges(at point: NSPoint, in bounds: NSRect) -> PanelEdges {
        guard bounds.contains(point) else { return [] }
        let corner = (point.x < bounds.minX + 14 || point.x > bounds.maxX - 14)
            && (point.y < bounds.minY + 14 || point.y > bounds.maxY - 14)
        let band: CGFloat = corner ? 14 : 8
        var result: PanelEdges = []
        if point.x < bounds.minX + band { result.insert(.left) }
        if point.x > bounds.maxX - band { result.insert(.right) }
        if point.y < bounds.minY + band { result.insert(.bottom) }
        if point.y > bounds.maxY - band { result.insert(.top) }
        return result
    }
    static func frame(start: NSRect, delta: NSSize, minimum: NSSize, maximum: NSSize, visible: NSRect?, edges: PanelEdges = [.right, .bottom]) -> NSRect {
        let horizontal = edges.contains(.left) || edges.contains(.right)
        let vertical = edges.contains(.top) || edges.contains(.bottom)
        let availableWidth = visible.map { edges.contains(.left) ? start.maxX - $0.minX : $0.maxX - start.minX } ?? maximum.width
        let availableHeight = visible.map { edges.contains(.top) ? $0.maxY - start.minY : start.maxY - $0.minY } ?? maximum.height
        let width = horizontal ? min(max(minimum.width, min(maximum.width, availableWidth)),
            max(minimum.width, start.width + (edges.contains(.left) ? -delta.width : delta.width))) : start.width
        let height = vertical ? min(max(minimum.height, min(maximum.height, availableHeight)),
            max(minimum.height, start.height + (edges.contains(.bottom) ? -delta.height : delta.height))) : start.height
        return NSRect(x: edges.contains(.left) ? start.maxX - width : start.minX,
                      y: edges.contains(.bottom) ? start.maxY - height : start.minY, width: width, height: height)
    }
}

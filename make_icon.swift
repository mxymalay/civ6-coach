import AppKit
let path = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let rect = NSRect(x: 40, y: 40, width: 944, height: 944)
let rounded = NSBezierPath(roundedRect: rect, xRadius: 214, yRadius: 214)
NSGradient(starting: NSColor(red: 0.16, green: 0.29, blue: 0.28, alpha: 1), ending: NSColor(red: 0.04, green: 0.09, blue: 0.10, alpha: 1))!.draw(in: rounded, angle: -65)
NSColor(red: 0.82, green: 0.70, blue: 0.46, alpha: 0.72).setStroke()
let ring = NSBezierPath(ovalIn: NSRect(x: 174, y: 174, width: 676, height: 676)); ring.lineWidth = 8; ring.stroke()
let inner = NSBezierPath(ovalIn: NSRect(x: 199, y: 199, width: 626, height: 626)); inner.lineWidth = 2; inner.stroke()
let font = NSFont(name: "TimesNewRomanPSMT", size: 310) ?? NSFont.systemFont(ofSize: 300, weight: .light)
let text = NSAttributedString(string: "VI", attributes: [.font: font, .foregroundColor: NSColor(red: 0.91, green: 0.81, blue: 0.60, alpha: 1)])
let ts = text.size(); text.draw(at: NSPoint(x: (1024-ts.width)/2, y: 343))
let dot = NSBezierPath(ovalIn: NSRect(x: 489, y: 235, width: 46, height: 46)); NSColor(red: 0.60, green: 0.84, blue: 0.72, alpha: 1).setFill(); dot.fill()
for side in [-1.0, 1.0] {
    for i in 0..<5 {
        let angle = Double(i) * 0.22 + 0.15
        let x = 512 + side * (205 + 85 * sin(angle))
        let y = 260 + Double(i)*75
        let leaf = NSBezierPath(ovalIn: NSRect(x: x-20, y: y, width: 30, height: 55))
        NSColor(red: 0.70, green: 0.78, blue: 0.61, alpha: 0.7).setFill(); leaf.fill()
    }
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))

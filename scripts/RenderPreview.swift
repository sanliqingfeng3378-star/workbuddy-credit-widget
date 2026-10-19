import AppKit
import SwiftUI

@main
struct RenderPreview {
    @MainActor static func main() throws {
        // Public screenshots always use synthetic data. Never load account caches.
        let preview = CreditPayload(snapshot: .preview, message: "样式预览 · 示例数据")
        let content = VStack(spacing: 18) {
            CreditCard(payload: preview).frame(width: 344, height: 170)
            CreditCard(payload: preview, paper: true).frame(width: 344, height: 170)
        }.padding(24).background(Color(red: 0.13, green: 0.16, blue: 0.17))
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        let icon = NSImage(size: NSSize(width: 1024, height: 1024))
        icon.lockFocus()
        NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.15, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 220, yRadius: 220).fill()
        let style: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 490, weight: .bold), .foregroundColor: NSColor(calibratedRed: 0.43, green: 0.91, blue: 0.70, alpha: 1)]
        ("W" as NSString).draw(at: NSPoint(x: 240, y: 230), withAttributes: style)
        NSColor(calibratedRed: 0.43, green: 0.91, blue: 0.70, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 700, y: 710, width: 100, height: 100)).fill()
        icon.unlockFocus()
        let directory = URL(fileURLWithPath: "Resources/AppIcon.iconset")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
                NSGraphicsContext.restoreGraphicsState()
                let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
                try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
            }
        }
    }
}

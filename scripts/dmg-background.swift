// Generates the DMG window background: swift scripts/dmg-background.swift scripts/dmg-background.tiff
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "scripts/dmg-background.tiff"
let W = 660, H = 400   // window content size in points; icons sit at (170,190) and (490,190) from the top-left

func render(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W * scale, pixelsHigh: H * scale, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

    // background
    let colors = [CGColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1), CGColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1)] as CFArray
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    cg.drawLinearGradient(g, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: 0, y: 0), options: [])

    // arrow between the two icons (y is flipped: icon centres are at 190 from the top)
    let y = CGFloat(H) - 190
    let accent = CGColor(red: 0.62, green: 0.55, blue: 1.0, alpha: 1)
    cg.setStrokeColor(accent); cg.setLineWidth(5); cg.setLineCap(.round); cg.setLineJoin(.round)
    cg.move(to: CGPoint(x: 268, y: y)); cg.addLine(to: CGPoint(x: 392, y: y)); cg.strokePath()
    cg.move(to: CGPoint(x: 370, y: y + 20)); cg.addLine(to: CGPoint(x: 394, y: y)); cg.addLine(to: CGPoint(x: 370, y: y - 20)); cg.strokePath()

    // text
    func draw(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, atY top: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(white: 1, alpha: alpha)]
        let str = NSAttributedString(string: s, attributes: attrs)
        let w = str.size().width
        str.draw(at: NSPoint(x: (CGFloat(W) - w) / 2, y: CGFloat(H) - top - size))
    }
    draw("Drag See Your Disk to Applications", size: 20, weight: .semibold, alpha: 0.92, atY: 44)
    draw("to install", size: 14, weight: .regular, alpha: 0.5, atY: 74)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let tmp = NSTemporaryDirectory()
var files: [String] = []
for scale in [1, 2] {
    let path = tmp + "dmgbg@\(scale)x.png"
    try! render(scale: scale).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    files.append(path)
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
p.arguments = ["-cathidpicheck", files[0], files[1], "-out", out]
try! p.run(); p.waitUntilExit()
print("wrote \(out)")

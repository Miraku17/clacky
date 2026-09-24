// Renders the Clacky app icon: a cream keycap on a deep-blue tile whose "C"
// legend throws off sound arcs. Usage: swift Tools/make-icon.swift <out-dir>
// Writes <out-dir>/icon-1024.png and <out-dir>/AppIcon.icns.
import AppKit
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/icon")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: 1) }

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
ctx.setShouldAntialias(true)

// Tile: macOS icon grid keeps content inside 824 pt of the 1024 canvas.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 184, yRadius: 184)
NSGradient(starting: rgb(38, 56, 84), ending: rgb(20, 31, 48))!.draw(in: tilePath, angle: -90)

// Keycap: a deeper base shows the side wall; the top face sits higher and lighter.
let base = CGRect(x: 232, y: 206, width: 560, height: 560)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: NSColor.black.withAlphaComponent(0.45).cgColor)
rgb(214, 198, 168).setFill()
NSBezierPath(roundedRect: base, xRadius: 88, yRadius: 88).fill()
ctx.restoreGState()
let face = CGRect(x: 262, y: 272, width: 500, height: 500)
let facePath = NSBezierPath(roundedRect: face, xRadius: 70, yRadius: 70)
NSGradient(starting: rgb(252, 247, 238), ending: rgb(240, 232, 216))!.draw(in: facePath, angle: -90)

// Legend "C", set like a real keycap legend: heavy, dark ink, sitting left of centre.
let ink = rgb(41, 42, 46)
let legend = NSAttributedString(string: "C", attributes: [
    .font: NSFont.systemFont(ofSize: 330, weight: .heavy), .foregroundColor: ink,
])
let legendSize = legend.size()
let legendOrigin = NSPoint(x: face.minX + 58, y: face.midY - legendSize.height / 2 + 6)
legend.draw(at: legendOrigin)

// Sound arcs leaving the C, in a mint that reads against both cream and blue.
let arcCenter = CGPoint(x: legendOrigin.x + legendSize.width - 28, y: face.midY + 6)
ctx.setStrokeColor(rgb(46, 178, 158).cgColor)
ctx.setLineCap(.round)
for (i, radius) in [84.0, 140.0, 196.0].enumerated() {
    ctx.setLineWidth(CGFloat(28 - i * 2))
    let path = NSBezierPath()
    path.appendArc(withCenter: arcCenter, radius: CGFloat(radius), startAngle: -34, endAngle: 34)
    ctx.addPath(path.cgPath)
    ctx.strokePath()
}

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
let master = outDir.appendingPathComponent("icon-1024.png")
try png.write(to: master)

// Iconset → icns
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, px) in [("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
                   ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
                   ("icon_512x512", 512), ("icon_512x512@2x", 1024)] {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    p.arguments = ["-z", "\(px)", "\(px)", master.path, "--out", iconset.appendingPathComponent("\(name).png").path]
    p.standardOutput = FileHandle.nullDevice
    try p.run(); p.waitUntilExit()
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outDir.appendingPathComponent("AppIcon.icns").path]
try iconutil.run(); iconutil.waitUntilExit()
print("wrote \(master.path) and AppIcon.icns (iconutil exit \(iconutil.terminationStatus))")

import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let icon = NSImage(size: NSSize(width: 1024, height: 1024), flipped: false) { _ in
  let background = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 204, yRadius: 204)
  NSGradient(starting: NSColor(white: 0.995, alpha: 1), ending: NSColor(white: 0.90, alpha: 1))!
    .draw(in: background, angle: -90)
  NSColor(white: 0.16, alpha: 1).setStroke()
  let dial = NSBezierPath(ovalIn: NSRect(x: 270, y: 206, width: 484, height: 484))
  dial.lineWidth = 36
  dial.stroke()
  NSColor(white: 0.16, alpha: 1).setFill()
  NSBezierPath(roundedRect: NSRect(x: 489, y: 707, width: 46, height: 62), xRadius: 10, yRadius: 10).fill()
  NSBezierPath(roundedRect: NSRect(x: 436, y: 765, width: 152, height: 42), xRadius: 18, yRadius: 18).fill()
  let side = NSBezierPath()
  side.move(to: NSPoint(x: 716, y: 701))
  side.line(to: NSPoint(x: 749, y: 734))
  side.lineWidth = 36
  side.lineCapStyle = .round
  side.stroke()
  let hand = NSBezierPath()
  hand.move(to: NSPoint(x: 512, y: 448))
  hand.line(to: NSPoint(x: 512, y: 608))
  hand.lineWidth = 25
  hand.lineCapStyle = .round
  NSColor.systemOrange.setStroke()
  hand.stroke()
  NSColor.systemOrange.setFill()
  NSBezierPath(ovalIn: NSRect(x: 493, y: 429, width: 38, height: 38)).fill()
  return true
}
for size in [16, 32, 128, 256, 512] {
  for factor in [1, 2] {
    let pixels = size * factor
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    icon.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.current = previous
    let suffix = factor == 2 ? "@2x" : ""
    try rep.representation(using: .png, properties: [:])!
      .write(to: output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
  }
}

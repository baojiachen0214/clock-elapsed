import AppKit
import SwiftUI

// Render the production row offscreen, without opening or changing Clock.
MainActor.assumeIsolated {
  let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
  let digit = ("0" as NSString).size(withAttributes: [.font: font]).width
  let separator = (":" as NSString).size(withAttributes: [.font: font]).width
  let icon = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: nil)!
    .withSymbolConfiguration(.init(pointSize: 12.5, weight: .regular))!
  icon.isTemplate = true
  let model = NumericTitleModel()
  for text in ["01:42", "01:00:00", "100:00:00"] {
    model.text = text
    let width = ceil(icon.size.width + 3 + text.reduce(CGFloat(0)) { $0 + ($1 == ":" ? separator : digit) })
    for dark in [false, true] {
      let renderer = ImageRenderer(content:
        NumericTitleView(model: model, icon: icon, digitWidth: digit, separatorWidth: separator)
          .frame(width: width, height: 24)
          .environment(\.colorScheme, dark ? .dark : .light)
          .background(dark ? Color(red: 0.15, green: 0.18, blue: 0.22) : Color(red: 149/255, green: 193/255, blue: 242/255)))
      renderer.scale = 2
      let cg = renderer.cgImage!
      precondition(cg.width == Int(width * 2) && cg.height == 48)
      let rep = NSBitmapImageRep(cgImage: cg)
      let name = "output/layout-\(text.replacingOccurrences(of: ":", with: "-"))-\(dark ? "dark" : "light").png"
      try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
      print(name, cg.width, cg.height)
    }
  }
}

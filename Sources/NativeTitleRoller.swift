import AppKit
import SwiftUI

/// One persistent renderer keeps the same glyphs, baseline and column positions
/// before, during and after the system numeric transition.
final class NativeTitleRoller {
  private weak var button: NSStatusBarButton?
  private let model = NumericTitleModel()
  private var host: PassiveNumericHost?
  private var currentTitle = ""
  private let digitWidth: CGFloat
  private let separatorWidth: CGFloat
  private let icon: NSImage

  init(button: NSStatusBarButton) {
    self.button = button
    let font = button.font ?? .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    digitWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
    separatorWidth = (":" as NSString).size(withAttributes: [.font: font]).width
    icon = button.image ?? NSImage(size: .zero)
    // Own the entire horizontal row. A cell title rectangle is a drawing rect,
    // not a reliable frame for a child hosting view in a flipped status button.
    button.image = nil
    button.imagePosition = .noImage
    button.title = ""
  }

  func width(for title: String) -> CGFloat {
    icon.size.width + 3 + title.reduce(0) { $0 + ($1 == ":" ? separatorWidth : digitWidth) }
  }

  func cancel() {
    host?.removeFromSuperview()
    host = nil
    currentTitle = ""
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) { model.text = "" }
  }

  func setTitle(_ title: String, animated: Bool) {
    guard let button, title != currentTitle else { return }
    let wasEmpty = currentTitle.isEmpty
    currentTitle = title

    if host == nil {
      let view = PassiveNumericHost(rootView: NumericTitleView(
        model: model, icon: icon, digitWidth: digitWidth, separatorWidth: separatorWidth))
      view.sizingOptions = []
      view.frame = button.bounds
      view.autoresizingMask = [.width, .height]
      button.addSubview(view)
      host = view
    }

    let shouldAnimate = animated && !wasEmpty &&
      !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    var transaction = Transaction(animation: shouldAnimate ? .default : nil)
    transaction.disablesAnimations = !shouldAnimate
    withTransaction(transaction) { model.text = title }
  }
}

final class NumericTitleModel: ObservableObject {
  @Published var text = ""
}

struct NumericTitleView: View {
  @ObservedObject var model: NumericTitleModel
  @Environment(\.colorScheme) private var colorScheme
  let icon: NSImage
  let digitWidth: CGFloat
  let separatorWidth: CGFloat

  var body: some View {
    // Identify columns from the right so seconds retain their identity when
    // hours first appear or grow beyond two digits. No horizontal interpolation.
    let columns = Array(model.text.reversed().enumerated()).reversed()
    HStack(spacing: 3) {
      Image(nsImage: icon)
        .renderingMode(.template)
        .frame(width: icon.size.width, height: icon.size.height)
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        ForEach(columns, id: \.offset) { column in
          if column.element == ":" {
            Text(":")
              .frame(width: separatorWidth)
              // A standalone SF colon sits below Clock's numeric colon.
              .offset(y: -1)
          } else {
            Text(String(column.element))
              // Reverse the observed physical motion: outgoing glyphs move up.
              // This affects presentation only; elapsed time still increases.
              .contentTransition(.numericText(countsDown: true))
              .frame(width: digitWidth)
              .transition(.identity)
          }
        }
      }
    }
    .font(.system(size: 11, weight: .regular).monospacedDigit())
    .lineLimit(1)
    .fixedSize(horizontal: true, vertical: true)
    // Match the status cell's neutral template ink. Vibrant primary text uses
    // a different compositing treatment and can acquire a blue fringe.
    .foregroundStyle((colorScheme == .dark ? Color.white : Color.black).opacity(0.85))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .offset(y: -0.5)
    .clipped()
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private final class PassiveNumericHost: NSHostingView<NumericTitleView> {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override var allowsVibrancy: Bool { false }
}

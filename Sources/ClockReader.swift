import AppKit
import ApplicationServices

/// Read-only bridge. Clock suspends its UI when hidden, so preserve a continuous-time
/// anchor and explicitly label local continuation until a fresh source sample arrives.
final class ClockReader {
  private let queue = DispatchQueue(label: "local.clockelapsed.reader", qos: .utility, autoreleaseFrequency: .workItem)
  private var timer: DispatchSourceTimer?
  private var clock: NSRunningApplication?
  private var application: AXUIElement?
  private var timeElement: AXUIElement?
  private var controlElement: AXUIElement?
  private var discoveryTime: TimeInterval = -.infinity
  private var sync = StopwatchSync()
  private var isClockActive = true
  private var parsedSample: (raw: String, seconds: TimeInterval)?
  var onSnapshot: ((ClockSnapshot) -> Void)?

  func start() {
    queue.async { [weak self] in
      guard let self else { return }
      guard self.timer == nil else { return }
      let timer = DispatchSource.makeTimerSource(queue: self.queue)
      timer.schedule(deadline: .now(), repeating: self.isClockActive ? 1 : 3, leeway: .milliseconds(100))
      timer.setEventHandler { [weak self] in
        guard let self else { return }
        let snapshot = autoreleasepool { self.read() }
        DispatchQueue.main.async { [weak self] in self?.onSnapshot?(snapshot) }
      }
      self.timer = timer
      timer.resume()
    }
  }

  func stop() {
    queue.sync {
      timer?.setEventHandler {}
      timer?.cancel()
      timer = nil
      clearElements()
      clock = nil
      application = nil
      sync = StopwatchSync()
    }
  }

  func setClockActive(_ active: Bool) {
    queue.async { [weak self] in
      guard let self, self.isClockActive != active else { return }
      self.isClockActive = active
      // Refresh immediately on activation, without a background tree scan every second.
      self.discoveryTime = -.infinity
      self.timer?.schedule(deadline: .now(), repeating: active ? 1 : 3, leeway: .milliseconds(100))
    }
  }

  deinit { timer?.cancel() }

  /// A user click may navigate Clock, but never changes a stopwatch or timer.
  func showStopwatch() {
    queue.async { [weak self] in self?.selectStopwatch(attempt: 0) }
  }

  private func selectStopwatch(attempt: Int) {
    guard timer != nil, AXIsProcessTrusted(),
      let clock = NSRunningApplication.runningApplications(withBundleIdentifier: ClockLifecycle.clockID).first else { return }
    let application = AXUIElementCreateApplication(clock.processIdentifier)
    AXUIElementSetMessagingTimeout(application, 0.2)
    var nodes = (attribute(application, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    var cursor = 0
    let deadline = ContinuousTime.now + 0.6
    let labels = ["Stopwatch", "秒表", "碼錶", "跑錶"]
    while cursor < nodes.count, cursor < 180, ContinuousTime.now < deadline {
      let node = nodes[cursor]
      cursor += 1
      if attribute(node, kAXRoleAttribute) as? String == kAXRadioButtonRole,
        strings(node).contains(where: { labels.contains($0) }) {
        if (attribute(node, kAXValueAttribute) as? NSNumber)?.intValue == 1 ||
          AXUIElementPerformAction(node, kAXPressAction as CFString) == .success {
          clearElements()
          return
        }
      }
      if let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
        nodes.append(contentsOf: children.prefix(max(0, 180 - nodes.count)))
      }
    }
    // Clock's View > Stopwatch command uses Command-3. Inspect its public AX
    // shortcut metadata as a locale-independent fallback; never inject keys.
    if let menu = attribute(application, kAXMenuBarAttribute), CFGetTypeID(menu) == AXUIElementGetTypeID() {
      nodes = [menu as! AXUIElement]
      cursor = 0
      while cursor < nodes.count, cursor < 140, ContinuousTime.now < deadline + 0.4 {
        let node = nodes[cursor]
        cursor += 1
        if attribute(node, kAXMenuItemCmdCharAttribute) as? String == "3",
          (attribute(node, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue == 0,
          AXUIElementPerformAction(node, kAXPressAction as CFString) == .success {
          clearElements()
          return
        }
        if let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] {
          nodes.append(contentsOf: children.prefix(max(0, 140 - nodes.count)))
        }
      }
    }
    if attempt < 4 {
      queue.asyncAfter(deadline: .now() + 0.15 * Double(attempt + 1)) { [weak self] in
        self?.selectStopwatch(attempt: attempt + 1)
      }
    }
  }

  private func read() -> ClockSnapshot {
    guard AXIsProcessTrusted() else {
      clearElements()
      sync = StopwatchSync()
      return ClockSnapshot(.permissionRequired)
    }
    if clock == nil || clock?.isTerminated == true {
      clearElements()
      application = nil
      sync = StopwatchSync()
      clock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.clock").first
      if let clock {
        application = AXUIElementCreateApplication(clock.processIdentifier)
        // A slow or unresponsive Clock must never block the menu bar's main thread.
        AXUIElementSetMessagingTimeout(application!, 0.2)
      }
    }
    guard let application else {
      sync = StopwatchSync()
      return ClockSnapshot(.clockClosed)
    }
    // Re-discover periodically so a detached element from another tab is never trusted forever.
    let discoveryInterval: TimeInterval = timeElement == nil || isClockActive ? 3 : 15
    if ContinuousTime.now - discoveryTime >= discoveryInterval {
      discover(in: application)
    }
    guard let timeElement else { return continuation() }
    let values = strings(timeElement)
    guard !values.isEmpty else {
      clearElements()
      return continuation()
    }
    guard let sample = values.lazy.compactMap({ raw -> (String, TimeInterval)? in
      if let cached = self.parsedSample, cached.raw == raw { return (raw, cached.seconds) }
      return ElapsedTime.parse(raw).map { (raw, $0) }
    }).first else {
      return ClockSnapshot(.unsupportedValue, rawValue: values.joined(separator: " | "))
    }
    parsedSample = (sample.0, sample.1)
    let running = controlElement.flatMap { element -> Bool? in
      let labels = strings(element).map { $0.lowercased() }
      if labels.contains(where: { ["stop", "停止"].contains($0) }) { return true }
      if labels.contains(where: { ["start", "resume", "启动", "啟動", "开始", "開始", "继续", "繼續"].contains($0) }) { return false }
      return nil
    }
    let now = ContinuousTime.now
    sync.receive(seconds: sample.1, running: running, at: now)
    guard let anchor = sync.anchor else { return ClockSnapshot(.stopwatchUnavailable) }
    let state: ClockSnapshot.State = sync.isProjected(at: now) ? .projected : .synchronized
    return ClockSnapshot(state, seconds: anchor.value(at: now), rawValue: sample.0, running: anchor.running)
  }

  private func continuation() -> ClockSnapshot {
    guard let anchor = sync.anchor else { return ClockSnapshot(.stopwatchUnavailable) }
    return ClockSnapshot(.projected, seconds: anchor.value(at: ContinuousTime.now), running: anchor.running)
  }

  private func clearElements() {
    timeElement = nil
    controlElement = nil
    parsedSample = nil
    discoveryTime = -.infinity
    if clock?.isTerminated == true {
      clock = nil
      application = nil
      sync = StopwatchSync()
    }
  }

  private func discover(in application: AXUIElement) {
    timeElement = nil
    controlElement = nil
    discoveryTime = ContinuousTime.now
    var elements = (attribute(application, kAXWindowsAttribute) as? [AXUIElement]) ?? []
    var cursor = 0
    let deadline = ContinuousTime.now + 0.6
    // Only Clock windows, with fixed work/time bounds; never scan other applications.
    while cursor < elements.count, cursor < 180, ContinuousTime.now < deadline {
      let element = elements[cursor]
      cursor += 1
      if let identifier = attribute(element, kAXIdentifierAttribute) as? String {
        if identifier == "stopwatch-time" { timeElement = element }
        if identifier == "StartStopButton" { controlElement = element }
      }
      if timeElement != nil, controlElement != nil { break }
      if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
        elements.append(contentsOf: children.prefix(max(0, 180 - elements.count)))
      }
    }
  }

  private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
  }

  private func strings(_ element: AXUIElement) -> [String] {
    var result: CFArray?
    let names = [kAXValueAttribute, kAXDescriptionAttribute, kAXTitleAttribute] as CFArray
    guard AXUIElementCopyMultipleAttributeValues(element, names, [], &result) == .success,
      let values = result as? [Any] else { return [] }
    return values.compactMap { $0 as? String }.filter { !$0.isEmpty }
  }
}

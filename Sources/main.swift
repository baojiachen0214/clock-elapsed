import AppKit
import ApplicationServices

private func localized(_ key: String) -> String {
  NSLocalizedString(key, bundle: .main, comment: "")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem?
  private var roller: NativeTitleRoller?
  private let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
  private let reader = ClockReader()
  private var tick: Timer?
  private var snapshot: ClockSnapshot?
  private var diagnostics: FileHandle?
  private var clockTermination: NSObjectProtocol?
  private var clockActivation: NSObjectProtocol?
  private var lastSeconds: Int?
  private var lastTooltip: String?
  private var lastTitleLength: Int?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    guard !NSRunningApplication.runningApplications(withBundleIdentifier: ClockLifecycle.clockID).isEmpty else {
      NSApp.terminate(nil)
      return
    }
    clockTermination = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
    ) { notification in
      let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      if ClockLifecycle.action(bundleID: application?.bundleIdentifier, launched: false) == .terminateCompanion {
        NSApp.terminate(nil)
      }
    }
    openDiagnosticsIfRequested()
    reader.setClockActive(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ClockLifecycle.clockID)
    clockActivation = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      self?.reader.setClockActive(application?.bundleIdentifier == ClockLifecycle.clockID)
    }
    if CommandLine.arguments.contains("--setup"), !AXIsProcessTrusted() {
      _ = AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }
    reader.onSnapshot = { [weak self] in self?.receive($0) }
    reader.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    reader.onSnapshot = nil
    reader.stop()
    tick?.invalidate()
    tick = nil
    roller?.cancel()
    roller = nil
    if let clockTermination { NSWorkspace.shared.notificationCenter.removeObserver(clockTermination) }
    if let clockActivation { NSWorkspace.shared.notificationCenter.removeObserver(clockActivation) }
    try? diagnostics?.close()
    if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    openClock()
    return false
  }

  private func receive(_ snapshot: ClockSnapshot) {
    self.snapshot = snapshot
    updateReadout()
    if let diagnostics {
      var record: [String: Any] = ["date": Date().timeIntervalSince1970, "state": snapshot.state.rawValue]
      if let seconds = snapshot.seconds { record["seconds"] = seconds }
      if let raw = snapshot.rawValue { record["source"] = raw }
      if let running = snapshot.running { record["running"] = running }
      if let lastSeconds { record["readout"] = ElapsedTime.display(Double(lastSeconds)) }
      if let statusItem { record["width"] = statusItem.length }
      if let appearance = statusItem?.button?.effectiveAppearance { record["appearance"] = appearance.name.rawValue }
      if var data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) {
        data.append(0x0A)
        try? diagnostics.write(contentsOf: data)
      }
    }
  }

  private func updateReadout() {
    tick?.invalidate()
    tick = nil
    guard let snapshot, let seconds = snapshot.value(at: ContinuousTime.now),
      seconds > 0 || snapshot.running == true else {
      if statusItem?.isVisible == true {
        statusItem?.isVisible = false
        roller?.cancel()
        lastSeconds = nil
      }
      return
    }
    let wholeSeconds = Int(floor(seconds))
    let title = ElapsedTime.display(Double(wholeSeconds))
    if statusItem == nil { createStatusItem() }
    if wholeSeconds != lastSeconds, let button = statusItem?.button {
      // Monospaced digits retain their width until the hours gain another digit.
      if title.count != lastTitleLength {
        let width = ceil(roller?.width(for: title) ?? 54)
        if statusItem?.length != width {
          statusItem?.length = width
          button.superview?.layoutSubtreeIfNeeded()
        }
        lastTitleLength = title.count
      }
      roller?.setTitle(title, animated: lastSeconds.map { wholeSeconds == $0 + 1 } ?? false)
      button.setAccessibilityValue(title)
      lastSeconds = wholeSeconds
    }
    if statusItem?.isVisible == false { statusItem?.isVisible = true }
    let tooltip = localized(snapshot.running == false ? "Clock · Paused" :
      snapshot.state == .projected ? "Clock hidden · Continuing locally" : "Clock · Synced")
    if tooltip != lastTooltip {
      statusItem?.button?.toolTip = tooltip
      lastTooltip = tooltip
    }
    if snapshot.running == true, snapshot.state == .projected {
      let timer = Timer(timeInterval: max(0.02, floor(seconds) + 1 - seconds), repeats: false) { [weak self] _ in
        self?.updateReadout()
      }
      RunLoop.main.add(timer, forMode: .common)
      tick = timer
    }
  }

  private func createStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: 54)
    let defaults = UserDefaults.standard
    let positionKey = "ClockElapsed.StatusAutosaveName"
    if let savedName = defaults.string(forKey: positionKey) { item.autosaveName = savedName }
    else if let name = item.autosaveName { defaults.set(name, forKey: positionKey) }
    statusItem = item
    guard let button = item.button else { return }
    button.font = font
    button.title = ""
    button.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: nil)?
      .withSymbolConfiguration(.init(pointSize: 12.5, weight: .regular))
    button.image?.isTemplate = true
    button.imagePosition = .imageLeading
    button.imageHugsTitle = true
    button.imageScaling = .scaleNone
    button.contentTintColor = nil
    button.target = self
    button.action = #selector(openClock)
    button.sendAction(on: [.leftMouseUp])
    button.setAccessibilityLabel(localized("Stopwatch"))
    roller = NativeTitleRoller(button: button)
  }

  @objc private func openClock() {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ClockLifecycle.clockID) else { return }
    NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] application, error in
      guard application != nil, error == nil else { return }
      self?.reader.showStopwatch()
    }
  }

  private func openDiagnosticsIfRequested() {
    guard let index = CommandLine.arguments.firstIndex(of: "--diagnostics"),
      CommandLine.arguments.indices.contains(index + 1) else { return }
    let path = CommandLine.arguments[index + 1]
    guard FileManager.default.createFile(atPath: path, contents: nil) else { return }
    diagnostics = FileHandle(forWritingAtPath: path)
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

import AppKit

private func text(_ key: String) -> String {
  NSLocalizedString(key, comment: "")
}

final class InstallerDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    let prompt = NSAlert()
    prompt.messageText = text("Install Clock Elapsed")
    prompt.informativeText = text("Add Clock’s stopwatch to your menu bar. Installs for your account; no administrator password needed.")
    prompt.addButton(withTitle: text("Install"))
    prompt.addButton(withTitle: text("Cancel"))
    guard prompt.runModal() == .alertFirstButtonReturn else { NSApp.terminate(nil); return }
    install()
  }

  private func install() {
    guard let resources = Bundle.main.resourceURL else { NSApp.terminate(nil); return }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/zsh")
    task.arguments = [resources.appendingPathComponent("install.sh").path,
      resources.appendingPathComponent("ClockElapsed.app").path]
    // Use a file rather than an undrained pipe: a failed tool cannot block setup.
    let logURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: logURL.path, contents: nil)
    defer { try? FileManager.default.removeItem(at: logURL) }
    do {
      let log = try FileHandle(forWritingTo: logURL)
      defer { try? log.close() }
      task.standardOutput = log
      task.standardError = log
      try task.run()
      task.waitUntilExit()
      guard task.terminationStatus == 0 else {
        let detail = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        throw NSError(domain: "ClockElapsedInstaller", code: Int(task.terminationStatus),
          userInfo: [NSLocalizedDescriptionKey: String(detail.suffix(2000))])
      }
      let done = NSAlert()
      done.messageText = text("Clock Elapsed is installed")
      done.informativeText = text("Allow Clock Elapsed in System Settings → Privacy & Security → Accessibility, then open Clock → Stopwatch. The companion follows Clock automatically.")
      done.addButton(withTitle: text("Open Settings"))
      done.addButton(withTitle: text("Done"))
      if done.runModal() == .alertFirstButtonReturn,
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
      }
    } catch {
      let alert = NSAlert(error: error)
      alert.messageText = text("Installation could not finish")
      alert.runModal()
    }
    NSApp.terminate(nil)
  }
}

let app = NSApplication.shared
let delegate = InstallerDelegate()
app.delegate = delegate
app.run()

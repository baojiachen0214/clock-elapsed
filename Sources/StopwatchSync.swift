import Foundation

/// Reject a frozen initial running value; continue locally only after seeing motion.
struct StopwatchSync {
  private(set) var anchor: ElapsedAnchor?
  private var candidate: (seconds: TimeInterval, at: TimeInterval)?
  private var lastSource: TimeInterval?
  private var lastChange: TimeInterval = 0

  mutating func receive(seconds: TimeInterval, running: Bool?, at now: TimeInterval) {
    guard let running else { return }
    if anchor == nil, running {
      defer { candidate = (seconds, now) }
      guard let candidate else { return }
      let elapsed = now - candidate.at
      let change = seconds - candidate.seconds
      guard elapsed > 0, elapsed < 5, change > 0,
        abs(change - elapsed) < max(0.35, elapsed * 0.35) else { return }
    }
    if lastSource != seconds || anchor?.running != running {
      anchor = ElapsedAnchor(seconds: seconds, capturedAt: now, running: running)
      lastChange = now
    }
    lastSource = seconds
  }

  func isProjected(at now: TimeInterval) -> Bool {
    anchor?.running == true && now - lastChange > 1.8
  }
}

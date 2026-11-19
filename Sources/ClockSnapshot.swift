import Foundation

struct ClockSnapshot {
  enum State: String {
    case permissionRequired, clockClosed, stopwatchUnavailable, unsupportedValue, synchronized, projected
  }
  let state: State
  let seconds: TimeInterval?
  let rawValue: String?
  let running: Bool?
  let sampledAt: TimeInterval

  init(_ state: State, seconds: TimeInterval? = nil, rawValue: String? = nil,
       running: Bool? = nil, sampledAt: TimeInterval = ContinuousTime.now) {
    self.state = state
    self.seconds = seconds
    self.rawValue = rawValue
    self.running = running
    self.sampledAt = sampledAt
  }

  func value(at now: TimeInterval) -> TimeInterval? {
    seconds.map { value in
      // Live Clock samples are authoritative. Interpolation can overshoot a pause
      // before the next sample arrives, briefly displaying a second in the future.
      value + (state == .projected && running == true ? max(0, now - sampledAt) : 0)
    }
  }
}

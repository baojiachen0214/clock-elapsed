import Darwin
import Foundation

enum ContinuousTime {
  private static let scale: Double = {
    var info = mach_timebase_info_data_t()
    mach_timebase_info(&info)
    return Double(info.numer) / Double(info.denom) / 1_000_000_000
  }()

  /// Includes sleep, and is unaffected by changes to the calendar clock.
  static var now: TimeInterval { Double(mach_continuous_time()) * scale }
}

struct ElapsedAnchor {
  let seconds: TimeInterval
  let capturedAt: TimeInterval
  let running: Bool

  func value(at now: TimeInterval) -> TimeInterval {
    seconds + (running ? max(0, now - capturedAt) : 0)
  }
}

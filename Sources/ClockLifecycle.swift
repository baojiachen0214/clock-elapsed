enum ClockLifecycle {
  static let clockID = "com.apple.clock"
  static let companionID = "local.clockelapsed.prototype"
  enum Action: Equatable { case launchCompanion, terminateCompanion, none }

  static func action(bundleID: String?, launched: Bool) -> Action {
    guard bundleID == clockID else { return .none }
    return launched ? .launchCompanion : .terminateCompanion
  }
}

import Foundation

let examples: [(String, Double)] = [
  ("00:04.15", 4.15), ("04:15.91", 255.91), ("1:02:03.45", 3723.45),
  ("100:02:03,45", 360123.45), ("4.15秒钟", 4.15), ("4.15秒鐘", 4.15),
  ("1分钟，4.15秒钟", 64.15), ("1小時 2分鐘 3.45秒鐘", 3723.45),
  ("1 hour, 2 minutes, 3.45 seconds", 3723.45), ("1 hr 2 mins 3.45 secs", 3723.45),
  ("0秒钟", 0), ("٠١:٠٢.٥٠", 62.5),
  ("\u{200E}00:04.15\u{200F}", 4.15), ("１:０２:０３.４５", 3723.45),
]
var checks = 0
for (input, expected) in examples {
  guard let value = ElapsedTime.parse(input), abs(value - expected) < 0.00001 else {
    fatalError("Failed to parse \(input): \(String(describing: ElapsedTime.parse(input))) != \(expected)")
  }
  checks += 1
}
for input in ["", "garbage", "-1秒", "1:60", "1:00:60", "0:00.1extra", "1秒 garbage 2分", "1 second warning", "NaN", String(repeating: "9", count: 201)] {
  guard ElapsedTime.parse(input) == nil else { fatalError("Unexpectedly accepted \(input)") }
  checks += 1
}
for (seconds, expected) in [(0.0, "00:00"), (4.99, "00:04"), (59.99, "00:59"), (60, "01:00"), (3600, "01:00:00"), (360000, "100:00:00")] {
  precondition(ElapsedTime.display(seconds) == expected)
  checks += 1
}
precondition(ElapsedTime.display(.infinity) == "—:—")
precondition(ElapsedTime.preciseDisplay(155.609) == "02:35.60")
precondition(ElapsedTime.preciseDisplay(59.999) == "00:59.99")
let running = ElapsedAnchor(seconds: 4.15, capturedAt: 100, running: true)
precondition(abs(running.value(at: 105) - 9.15) < 0.00001)
let paused = ElapsedAnchor(seconds: 4.15, capturedAt: 100, running: false)
precondition(paused.value(at: 10000) == 4.15)
precondition(running.value(at: 99) == 4.15)
let calibrated = ElapsedAnchor(seconds: 3, capturedAt: 110, running: false)
precondition(calibrated.value(at: 111) == 3)
checks += 7
var sync = StopwatchSync()
sync.receive(seconds: 10, running: true, at: 100)
precondition(sync.anchor == nil)
sync.receive(seconds: 10, running: true, at: 101)
precondition(sync.anchor == nil)
sync.receive(seconds: 25, running: true, at: 102)
precondition(sync.anchor == nil)
sync.receive(seconds: 26, running: true, at: 103)
precondition(sync.anchor?.value(at: 105) == 28)
precondition(sync.isProjected(at: 106))
sync.receive(seconds: 26, running: true, at: 110)
precondition(sync.anchor?.value(at: 110) == 33)
sync.receive(seconds: 40, running: false, at: 111)
precondition(sync.anchor?.value(at: 200) == 40)
sync.receive(seconds: 0, running: false, at: 112)
precondition(sync.anchor?.value(at: 201) == 0)
sync.receive(seconds: 0.5, running: true, at: 113)
precondition(sync.anchor?.value(at: 114) == 1.5)
sync.receive(seconds: 0.5, running: nil, at: 115)
precondition(sync.anchor?.running == true)
checks += 10
precondition(ClockLifecycle.action(bundleID: "com.apple.clock", launched: true) == .launchCompanion)
precondition(ClockLifecycle.action(bundleID: "com.apple.clock", launched: false) == .terminateCompanion)
precondition(ClockLifecycle.action(bundleID: "com.apple.finder", launched: true) == .none)
precondition(ClockLifecycle.action(bundleID: nil, launched: false) == .none)
checks += 4
// A pause between source reads must not reveal a future whole second and then roll back.
let live = ClockSnapshot(.synchronized, seconds: 2.28, running: true, sampledAt: 100)
precondition(live.value(at: 101) == 2.28)
precondition(ElapsedTime.display(live.value(at: 101)!) == "00:02")
let stopped = ClockSnapshot(.synchronized, seconds: 2.3, running: false, sampledAt: 101)
precondition(ElapsedTime.display(stopped.value(at: 102)!) == "00:02")
let hidden = ClockSnapshot(.projected, seconds: 2.28, running: true, sampledAt: 100)
precondition(abs(hidden.value(at: 101)! - 3.28) < 0.00001)
precondition(ElapsedTime.display(2.99999999) == "00:02")
checks += 5
for (seconds, expected) in [
  (3599.0, "59:59"), (3600.0, "01:00:00"),
  (35999.0, "09:59:59"), (36000.0, "10:00:00"),
  (359999.0, "99:59:59"), (360000.0, "100:00:00"),
  (3599999.0, "999:59:59"), (3600000.0, "1000:00:00"),
] {
  precondition(ElapsedTime.display(seconds) == expected)
  checks += 1
}
print("Passed \(checks) parsing, synchronization and lifecycle checks.")

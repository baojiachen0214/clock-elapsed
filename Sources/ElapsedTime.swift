import Foundation

enum ElapsedTime {
  private static let clockPattern = try! NSRegularExpression(
    pattern: "^[0-9]+:[0-9]{2}(?::[0-9]{2})?(?:[.,][0-9]+)?$")
  private static let unitsPattern = try! NSRegularExpression(
    pattern: "([0-9]+(?:[.,][0-9]+)?)\\s*(小时|小時|分钟|分鐘|秒钟|秒鐘|hours?|minutes?|seconds?|hrs?|mins?|secs?|时|時|分|秒|h|m|s)",
    options: .caseInsensitive)

  /// Clock can expose either its digital display or a localized spoken duration.
  static func parse(_ source: String) -> TimeInterval? {
    guard source.count <= 200 else { return nil }
    var text = ""
    for scalar in source.unicodeScalars {
      if CharacterSet.decimalDigits.contains(scalar), let digit = Character(String(scalar)).wholeNumberValue {
        text += String(digit)
      } else if !CharacterSet.controlCharacters.contains(scalar), ![0x200E, 0x200F, 0x202A, 0x202B, 0x202C].contains(scalar.value) {
        text.unicodeScalars.append(scalar)
      }
    }
    text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(text.startIndex..., in: text)
    if clockPattern.firstMatch(in: text, range: range) != nil {
      let parts = text.replacingOccurrences(of: ",", with: ".").split(separator: ":")
      let values = parts.compactMap { Double($0) }
      guard values.count == parts.count, values.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
      return bounded(values.reduce(0) { $0 * 60 + $1 })
    }
    let matches = unitsPattern.matches(in: text, range: range)
    guard !matches.isEmpty else { return nil }
    var total: Double = 0
    var end = text.startIndex
    for match in matches {
      guard let whole = Range(match.range, in: text), let number = Range(match.range(at: 1), in: text),
        let unitRange = Range(match.range(at: 2), in: text),
        text[end..<whole.lowerBound].allSatisfy({ $0.isWhitespace || "，,、".contains($0) }),
        let value = Double(text[number].replacingOccurrences(of: ",", with: "."))
      else { return nil }
      let unit = text[unitRange].lowercased()
      let multiplier: Double
      if unit.hasPrefix("h") || ["小时", "小時", "时", "時"].contains(unit) { multiplier = 3600 }
      else if unit.hasPrefix("m") || ["分钟", "分鐘", "分"].contains(unit) { multiplier = 60 }
      else { multiplier = 1 }
      total += value * multiplier
      end = whole.upperBound
    }
    guard text[end...].allSatisfy({ $0.isWhitespace }) else { return nil }
    return bounded(total)
  }

  static func display(_ seconds: TimeInterval) -> String {
    guard let value = bounded(seconds) else { return "—:—" }
    let total = Int(floor(value))
    if total >= 3600 {
      return padded(total / 3600) + ":" + padded(total / 60 % 60) + ":" + padded(total % 60)
    }
    return padded(total / 60) + ":" + padded(total % 60)
  }

  static func preciseDisplay(_ seconds: TimeInterval) -> String {
    guard let value = bounded(seconds) else { return "—:—.——" }
    let hundredths = Int(floor(value * 100))
    return display(Double(hundredths / 100)) + "." + padded(hundredths % 100)
  }

  private static func padded(_ value: Int) -> String { value < 10 ? "0\(value)" : String(value) }

  private static func bounded(_ value: Double) -> Double? {
    value.isFinite && value >= 0 && value < 10_000_000_000 ? value : nil
  }
}

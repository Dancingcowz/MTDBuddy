import Foundation

extension Date {
    /// Whole minutes from now to this date (can be negative if it's already passed).
    var minutesFromNow: Int {
        Int((timeIntervalSinceNow / 60).rounded())
    }

    /// "mm:ss" countdown string, clamped to "00:00" once passed.
    func countdownString(from reference: Date = Date()) -> String {
        let seconds = max(0, Int(timeIntervalSince(reference)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

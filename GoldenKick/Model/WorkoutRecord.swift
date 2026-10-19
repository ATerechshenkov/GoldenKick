import Foundation
import SwiftData

/// A completed workout, stored for the history tab. Only fully finished workouts
/// (not stopped early, not run in fast mode) are recorded — see `ContentView`.
@Model
final class WorkoutRecord {
    /// When the workout was started.
    var startDate: Date
    /// `WorkoutConfig.title` at the time the workout was started.
    var title: String

    /// Nominal durations in seconds, as configured when the workout was started.
    var warmup: TimeInterval
    var run: TimeInterval
    var walk: TimeInterval
    var cooldown: TimeInterval
    var reps: Int

    /// Real seconds of workout time, pauses excluded.
    var activeDuration: TimeInterval
    /// Total time spent running across all intervals.
    var runDuration: TimeInterval

    init(
        startDate: Date,
        title: String,
        warmup: TimeInterval,
        run: TimeInterval,
        walk: TimeInterval,
        cooldown: TimeInterval,
        reps: Int,
        activeDuration: TimeInterval,
        runDuration: TimeInterval
    ) {
        self.startDate = startDate
        self.title = title
        self.warmup = warmup
        self.run = run
        self.walk = walk
        self.cooldown = cooldown
        self.reps = reps
        self.activeDuration = activeDuration
        self.runDuration = runDuration
    }
}

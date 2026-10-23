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

    /// The plan day (start of day) this record fulfills, if it was started
    /// from the training plan. `nil` for workouts run outside the plan (and
    /// for older records, predating this field).
    var planDate: Date?

    init(
        startDate: Date,
        title: String,
        warmup: TimeInterval,
        run: TimeInterval,
        walk: TimeInterval,
        cooldown: TimeInterval,
        reps: Int,
        activeDuration: TimeInterval,
        runDuration: TimeInterval,
        planDate: Date? = nil
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
        self.planDate = planDate
    }
}

extension WorkoutRecord {
    /// A race finish: no timer involved, so all durations are zero.
    static func raceFinish(_ race: Race, planDate: Date, finishedAt: Date = .now) -> WorkoutRecord {
        WorkoutRecord(
            startDate: finishedAt,
            title: race.name,
            warmup: 0,
            run: 0,
            walk: 0,
            cooldown: 0,
            reps: 0,
            activeDuration: 0,
            runDuration: 0,
            planDate: planDate
        )
    }
}

import ActivityKit
import SwiftUI

/// The physical activity performed during a segment, independent of its role
/// (warm-up/interval/cool-down) in the workout. Named distinctly from ActivityKit's
/// `Activity` type, which this file also uses.
enum ExerciseKind: Codable, Hashable {
    case run, walk
}

enum SegmentKind: Codable, Hashable {
    case warmup, run, walk, cooldown

    /// The activity a person actually performs during this segment.
    var activity: ExerciseKind {
        switch self {
        case .run: .run
        case .walk, .warmup, .cooldown: .walk
        }
    }

    var title: String {
        switch self {
        case .warmup: "РАЗМИНКА"
        case .run: "БЕГ"
        case .walk: "ШАГ"
        case .cooldown: "ЗАМИНКА"
        }
    }

    var listTitle: String {
        switch self {
        case .warmup: "Разминка (шаг)"
        case .run: "Бег"
        case .walk: "Шаг"
        case .cooldown: "Заминка (шаг)"
        }
    }

    /// Used in "Дальше: …".
    var nextTitle: String {
        switch self {
        case .warmup: "разминка"
        case .run: "бег"
        case .walk: "шаг"
        case .cooldown: "заминка"
        }
    }

    var color: Color {
        switch self {
        case .run: .orange
        case .walk: .green
        case .warmup, .cooldown: .blue
        }
    }

    /// SF Symbol shown in the Live Activity / Dynamic Island.
    var symbolName: String {
        switch activity {
        case .run: "figure.run"
        case .walk: "figure.walk"
        }
    }
}

enum TimeFormat {
    static func mmss(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Shared between the app and the widget extension to drive the workout's Live Activity.
/// Explicitly non-isolated: ActivityKit stores and decodes this off the main actor,
/// which conflicts with this project's default main-actor isolation.
nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    let workoutTitle: String

    nonisolated struct ContentState: Codable, Hashable {
        var kind: SegmentKind
        /// nil while paused — the countdown is frozen then.
        var segmentEnd: Date?
        /// Shown instead of a live countdown while paused.
        var pausedRemaining: TimeInterval
        var workoutStart: Date
        var workoutEnd: Date
        /// Static progress fraction, used while paused (the live progress bar
        /// otherwise advances on its own between workoutStart and workoutEnd).
        var progress: Double
        /// "Интервал 3 из 6", nil for warm-up/cool-down.
        var intervalText: String?
        /// "Дальше: шаг 2:00" or "Последний отрезок".
        var nextText: String
        var isPaused: Bool
        var isFinished: Bool
    }
}

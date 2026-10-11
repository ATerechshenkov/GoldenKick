import SwiftUI

/// The physical activity performed during a segment, independent of its role
/// (warm-up/interval/cool-down) in the workout.
enum Activity {
    case run, walk
}

enum SegmentKind: Equatable {
    case warmup, run, walk, cooldown

    /// The activity a person actually performs during this segment.
    var activity: Activity {
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
}

struct Segment: Identifiable {
    let id: Int
    let kind: SegmentKind
    /// Nominal duration in seconds (before any debug time scaling).
    let duration: TimeInterval
    let repIndex: Int?
}

struct WorkoutConfig {
    var warmup: TimeInterval
    var run: TimeInterval
    var walk: TimeInterval
    var cooldown: TimeInterval
    var reps: Int
    /// Activity performed during the warm-up. If it matches the first interval
    /// exercise, that exercise is dropped to avoid two identical activities in a row.
    var warmupActivity: Activity = .walk
    /// Activity performed during the cool-down. If it matches the last interval
    /// exercise, that exercise is dropped to avoid two identical activities in a row.
    var cooldownActivity: Activity = .walk

    /// The single place where the workout is defined.
    static let current = WorkoutConfig(warmup: 5 * 60, run: 1 * 60, walk: 2 * 60, cooldown: 5 * 60, reps: 6)

    var title: String {
        "Бег \(Self.shortMinutes(run)) / шаг \(Self.shortMinutes(walk)) × \(reps)"
    }

    /// Sum of the actual segments after warm-up/cool-down de-duplication.
    var totalDuration: TimeInterval {
        makeSegments().reduce(0) { $0 + $1.duration }
    }

    func makeSegments() -> [Segment] {
        // Rep numbers are attached before any dropping below, so the interval
        // countdown always refers to the originally configured rep, even if its
        // run (or walk) was merged away.
        var intervals: [(SegmentKind, TimeInterval, Int)] = []
        for rep in 1...max(reps, 1) {
            intervals.append((.run, run, rep))
            intervals.append((.walk, walk, rep))
        }

        // Drop the first interval exercise if the warm-up is the same activity,
        // and the last one if the cool-down is the same activity, so the same
        // activity is never performed twice in a row.
        if let first = intervals.first, first.0.activity == warmupActivity {
            intervals.removeFirst()
        }
        if let last = intervals.last, last.0.activity == cooldownActivity {
            intervals.removeLast()
        }

        var kinds: [(SegmentKind, TimeInterval, Int?)] = [(.warmup, warmup, nil)]
        kinds.append(contentsOf: intervals.map { ($0.0, $0.1, $0.2) })
        kinds.append((.cooldown, cooldown, nil))
        return kinds.enumerated().map { index, item in
            Segment(id: index, kind: item.0, duration: item.1, repIndex: item.2)
        }
    }

    private static func shortMinutes(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return s % 60 == 0 ? "\(s / 60) мин" : TimeFormat.mmss(seconds)
    }
}

enum TimeFormat {
    static func mmss(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

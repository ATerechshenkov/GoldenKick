import Foundation

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
    var warmupActivity: ExerciseKind = .walk
    /// Activity performed during the cool-down. If it matches the last interval
    /// exercise, that exercise is dropped to avoid two identical activities in a row.
    var cooldownActivity: ExerciseKind = .walk

    var title: String {
        guard reps > 1 || walk > 0 else {
            return "Бег \(Self.shortMinutes(run))"
        }
        return "Бег \(Self.shortMinutes(run)) / шаг \(Self.shortMinutes(walk)) × \(reps)"
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

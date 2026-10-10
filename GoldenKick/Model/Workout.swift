import SwiftUI

enum SegmentKind {
    case warmup, run, walk, cooldown

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

    /// Used in "Через десять секунд — …" and "Дальше: …".
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

    /// The single place where the workout is defined.
    static let current = WorkoutConfig(warmup: 5 * 60, run: 1 * 60, walk: 2 * 60, cooldown: 5 * 60, reps: 6)

    var title: String {
        "Бег \(Self.shortMinutes(run)) / шаг \(Self.shortMinutes(walk)) × \(reps)"
    }

    var totalDuration: TimeInterval {
        warmup + Double(reps) * (run + walk) + cooldown
    }

    func makeSegments() -> [Segment] {
        var kinds: [(SegmentKind, TimeInterval, Int?)] = [(.warmup, warmup, nil)]
        for rep in 1...max(reps, 1) {
            kinds.append((.run, run, rep))
            kinds.append((.walk, walk, rep))
        }
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

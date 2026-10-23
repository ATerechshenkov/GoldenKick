import Foundation

enum PlanDayStatus {
    case done, upcoming, missed
}

/// Read-only view over completed workouts, used to resolve each plan day's
/// status. Built fresh from the current `WorkoutRecord`s each time — nothing
/// here is persisted itself.
struct PlanProgress {
    private let records: [WorkoutRecord]

    init(records: [WorkoutRecord]) {
        self.records = records
    }

    /// The record that fulfills this plan day, if any.
    func record(for day: PlanDay) -> WorkoutRecord? {
        records.first { $0.planDate.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false }
    }

    func status(of day: PlanDay, today: Date = .now) -> PlanDayStatus {
        if record(for: day) != nil { return .done }
        return day.date >= Calendar.current.startOfDay(for: today) ? .upcoming : .missed
    }

    /// `true` only on the plan day's own calendar date, and only if it isn't
    /// done yet — this gates both "Начать" and "Финишировал".
    func canStart(_ day: PlanDay, today: Date = .now) -> Bool {
        guard record(for: day) == nil else { return false }
        return Calendar.current.isDate(day.date, inSameDayAs: today)
    }

    /// The earliest unfinished plan day on or after `today`.
    func nextIncomplete(from today: Date = .now) -> PlanDay? {
        let start = Calendar.current.startOfDay(for: today)
        return TrainingPlan.days.first { $0.date >= start && record(for: $0) == nil }
    }

    /// `true` if today has a scheduled workout and it's already done.
    func isTodayDone(today: Date = .now) -> Bool {
        guard let day = TrainingPlan.workout(on: today) else { return false }
        return record(for: day) != nil
    }
}

/// Logic for the Russian day/status text shown on the plan UI, kept out of
/// the views so it stays testable.
enum PlanText {
    /// "Сегодня", "Завтра", "Послезавтра", "Через 5 дней", ...
    static func relativeDay(_ date: Date, from today: Date = .now) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: today),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case 0: return "Сегодня"
        case 1: return "Завтра"
        case 2: return "Послезавтра"
        default:
            let word = RussianNumerals.plural(days, one: "день", few: "дня", many: "дней")
            return "Через \(RussianNumerals.cardinal(days)) \(word)"
        }
    }

    /// "чт, 29 окт."
    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate("EEEEEE, d MMM")
        return formatter.string(from: date)
    }

    /// "18 апреля 2027 г."
    static func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// "воскресенье, 18 апреля 2027 г."
    static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// "Сегодня!", "через 5 дн.", "через 3 нед." — for a future/today date.
    static func countdown(to date: Date, from today: Date = .now) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: today),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        if days == 0 { return "Сегодня!" }
        if days <= 14 { return "через \(days) дн." }
        return "через \(days / 7) нед."
    }

    static func statusTitle(_ status: PlanDayStatus) -> String {
        switch status {
        case .done: "Выполнена"
        case .upcoming: "Предстоит"
        case .missed: "Пропущена"
        }
    }
}

extension PlannedWorkout {
    /// "≈ 31 мин", rounded to the nearest minute. `nil` for races.
    var approxMinutesText: String? {
        guard let duration = totalDuration else { return nil }
        return "≈ \(Int((duration / 60).rounded())) мин"
    }
}

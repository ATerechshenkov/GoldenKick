import Foundation

enum PlanDayStatus {
    case done, upcoming, missed, madeUp
}

/// Why a missed workout can't be made up right now.
enum MakeupBlocker {
    case todayHasOwnWorkout, alreadyTrainedToday, tooLate
}

extension WorkoutRecord {
    /// A make-up run: started on a different day than the plan day it fulfills.
    var isMakeup: Bool {
        guard let planDate else { return false }
        return !Calendar.current.isDate(planDate, inSameDayAs: startDate)
    }
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
        if let record = record(for: day) { return record.isMakeup ? .madeUp : .done }
        return day.date >= Calendar.current.startOfDay(for: today) ? .upcoming : .missed
    }

    /// The make-up run that was started on this calendar day, if any.
    func makeupRecord(on date: Date) -> WorkoutRecord? {
        records.first { $0.isMakeup && Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    /// `nil` if a missed workout can be made up today; otherwise the first
    /// reason it can't.
    func makeupBlocker(for day: PlanDay, today: Date = .now) -> MakeupBlocker? {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: day.date),
            to: calendar.startOfDay(for: today)
        ).day ?? 0
        if days > 7 { return .tooLate }
        if TrainingPlan.workout(on: today) != nil { return .todayHasOwnWorkout }
        if records.contains(where: { calendar.isDate($0.startDate, inSameDayAs: today) }) {
            return .alreadyTrainedToday
        }
        return nil
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
        case .madeUp: "Отработана"
        }
    }

    static func makeupBlockerText(_ blocker: MakeupBlocker) -> String {
        switch blocker {
        case .todayHasOwnWorkout: "Сегодня по плану своя тренировка"
        case .alreadyTrainedToday: "Сегодня тренировка уже была"
        case .tooLate: "Отработать можно в течение 7 дней"
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

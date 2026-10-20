import Foundation

/// A single race slot resolved to its plan position, for display in lists.
struct RaceEntry: Identifiable {
    let slot: PlanSlot
    let race: Race
    var id: PlanSlot { slot }
}

/// Read-only view over completed workouts, used to answer "what's left this
/// week" / "what happened on which day" questions. Built fresh from the
/// current `WorkoutRecord`s each time — nothing here is persisted itself.
struct PlanProgress {
    private let records: [WorkoutRecord]

    init(records: [WorkoutRecord]) {
        self.records = records
    }

    func isDone(week: Int, slot: Int) -> Bool {
        records.contains { $0.planWeek == week && $0.planSlot == slot }
    }

    func isWeekDone(_ week: TrainingWeek) -> Bool {
        (1...3).allSatisfy { isDone(week: week.number, slot: $0) }
    }

    func firstIncompleteSlot(in week: TrainingWeek) -> Int? {
        (1...3).first { !isDone(week: week.number, slot: $0) }
    }

    /// Calendar days (start of day) on which a record for this week was started.
    func completionDays(in week: TrainingWeek) -> Set<Date> {
        let calendar = Calendar.current
        return Set(records.compactMap { record in
            guard record.planWeek == week.number else { return nil }
            return calendar.startOfDay(for: record.startDate)
        })
    }

    /// `true` if a record exists for this race slot (finished).
    func raceFinished(_ slot: PlanSlot) -> Bool {
        isDone(week: slot.week, slot: slot.slot)
    }
}

extension PlanProgress {
    /// Every race slot in the plan, in week order.
    static var raceSlots: [RaceEntry] {
        TrainingPlan.weeks.flatMap { week in
            week.workouts.enumerated().compactMap { index, workout in
                workout.asRace.map { RaceEntry(slot: PlanSlot(week: week.number, slot: index + 1), race: $0) }
            }
        }
    }

    /// The 7 calendar days (Mon...Sun) that make up a plan week.
    static func days(of week: TrainingWeek) -> [Date] {
        let calendar = Calendar.current
        let weekStart = calendar.date(byAdding: .day, value: (week.number - 1) * 7, to: TrainingPlan.startDate)!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    static func nextWeek(after week: TrainingWeek) -> TrainingWeek? {
        TrainingPlan.weeks.first { $0.number == week.number + 1 }
    }
}

extension PlannedWorkout {
    /// "≈ 31 мин", rounded to the nearest minute. `nil` for races.
    var approxMinutesText: String? {
        guard let duration = totalDuration else { return nil }
        return "≈ \(Int((duration / 60).rounded())) мин"
    }
}

import Foundation

/// A single goal the plan is building towards (a race, in code).
struct Race: Hashable {
    let name: String
    let date: Date
}

enum TrainingPhase {
    case base, development, long, races

    var title: String {
        switch self {
        case .base: "База"
        case .development: "Развитие"
        case .long: "Длинные"
        case .races: "Старты"
        }
    }
}

/// What a plan day consists of: either a workout to run through the timer,
/// or a race day (no timer — the person just marks it finished).
enum PlannedWorkout {
    case workout(WorkoutConfig)
    case race(Race)

    var title: String {
        switch self {
        case .workout(let config): config.title
        case .race(let race): race.name
        }
    }

    /// Approximate duration shown in the list. `nil` for races.
    var totalDuration: TimeInterval? {
        switch self {
        case .workout(let config): config.totalDuration
        case .race: nil
        }
    }

    var asRace: Race? {
        if case .race(let race) = self { return race }
        return nil
    }
}

struct TrainingWeek {
    /// Exactly 3 slots: Tuesday, Thursday, Saturday (unless overridden by a race date).
    let workouts: [PlannedWorkout]
    let phase: TrainingPhase
}

/// One calendar day on which the plan has something scheduled.
struct PlanDay: Identifiable, Hashable {
    /// Start of day.
    let date: Date
    let workout: PlannedWorkout
    let phase: TrainingPhase
    var id: Date { date }

    static func == (lhs: PlanDay, rhs: PlanDay) -> Bool { lhs.date == rhs.date }
    func hash(into hasher: inout Hasher) { hasher.combine(date) }
}

/// The 26-week plan leading up to the half marathon, as hand-edited static data.
/// Not stored in a database on purpose — edit the `weeks` table below directly
/// to adjust the plan.
enum TrainingPlan {
    /// Monday the plan starts. Slot 1 of week 1 falls on the Tuesday after.
    static let startDate = date(year: 2026, month: 10, day: 19)

    static let roadRace = Race(name: "RoadRace 10 км", date: date(year: 2027, month: 4, day: 4))
    static let halfMarathon = Race(name: "Алматинский полумарафон 21 км", date: date(year: 2027, month: 4, day: 18))

    /// Last day the plan covers — the half marathon itself.
    static var endDate: Date { halfMarathon.date }

    /// Every scheduled day in the plan, in chronological order.
    static let days: [PlanDay] = {
        let calendar = Calendar.current
        // Tue, Thu, Sat offsets from each week's Monday.
        let slotOffsets = [1, 3, 5]
        return weeks.enumerated().flatMap { weekIndex, week -> [PlanDay] in
            let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: startDate)!
            return week.workouts.enumerated().map { slotIndex, workout in
                let date: Date
                if case .race(let race) = workout {
                    date = calendar.startOfDay(for: race.date)
                } else {
                    date = calendar.date(byAdding: .day, value: slotOffsets[slotIndex], to: weekStart)!
                }
                return PlanDay(date: date, workout: workout, phase: week.phase)
            }
        }.sorted { $0.date < $1.date }
    }()

    /// The plan day falling on this calendar date, if any. `nil` on rest days.
    static func workout(on date: Date) -> PlanDay? {
        let day = Calendar.current.startOfDay(for: date)
        return days.first { $0.date == day }
    }

    /// Every race day in the plan, in chronological order.
    static var raceDays: [PlanDay] { days.filter { $0.workout.asRace != nil } }

    /// Used to seed `WorkoutEngine` before any plan day has been picked.
    /// The first scheduled day is always a `.workout`, never a race.
    static var firstWorkoutConfig: WorkoutConfig {
        guard case .workout(let config) = days[0].workout else {
            preconditionFailure("First plan day must be a workout")
        }
        return config
    }

    // MARK: - The plan itself (slot 1 / slot 2 / slot 3 per week)

    static let weeks: [TrainingWeek] = [
        week(1, intervals(5, run: 3, walk: 1.5), intervals(5, run: 3, walk: 1.5), intervals(5, run: 3, walk: 1.5)),
        week(2, intervals(4, run: 5, walk: 1.5), intervals(4, run: 5, walk: 1.5), intervals(4, run: 5, walk: 1.5)),
        week(3, intervals(3, run: 8, walk: 1.5), intervals(3, run: 8, walk: 1.5), intervals(3, run: 8, walk: 1.5)),
        week(4, intervals(4, run: 5, walk: 1.5), intervals(4, run: 5, walk: 1.5), intervals(4, run: 5, walk: 1.5)),
        week(5, intervals(2, run: 12, walk: 1.5), intervals(2, run: 12, walk: 1.5), continuous(20)),
        week(6, continuous(20), continuous(20), continuous(25)),
        week(7, continuous(25), continuous(25), continuous(30)),
        week(8, continuous(20), continuous(20), continuous(25)),
        week(9, continuous(30), continuous(30), continuous(35)),
        week(10, continuous(30), continuous(30), continuous(40)),
        week(11, continuous(35), continuous(30), continuous(45)),
        week(12, continuous(30), continuous(25), continuous(35)),
        week(13, continuous(35), continuous(35), continuous(50)),
        week(14, continuous(40), continuous(35), continuous(60)),
        week(15, continuous(40), continuous(35), continuous(70)),
        week(16, continuous(35), continuous(30), continuous(55)),
        week(17, continuous(40), continuous(40), continuous(80)),
        week(18, continuous(40), continuous(40), continuous(85)),
        week(19, continuous(45), continuous(40), continuous(95)),
        week(20, continuous(35), continuous(35), continuous(70)),
        week(21, continuous(45), continuous(40), continuous(100)),
        week(22, continuous(45), continuous(40), continuous(110)),
        week(23, continuous(45), continuous(40), continuous(120)),
        week(24, continuous(40), continuous(25), .race(roadRace)),
        week(25, continuous(30), continuous(40), continuous(95)),
        week(26, continuous(30), continuous(20), .race(halfMarathon)),
    ]
}

// MARK: - Plan table builders

/// Interval workout: N reps of run/walk, bracketed by a 5-minute walking
/// warm-up and cool-down.
private func intervals(_ reps: Int, run: Double, walk: Double) -> PlannedWorkout {
    .workout(WorkoutConfig(warmup: 5 * 60, run: run * 60, walk: walk * 60, cooldown: 5 * 60, reps: reps))
}

/// Continuous run of N minutes: a 5-minute walking warm-up, the run itself as
/// a single rep with no walk interval, and a 5-minute walking cool-down.
private func continuous(_ minutes: Int) -> PlannedWorkout {
    .workout(WorkoutConfig(warmup: 5 * 60, run: Double(minutes) * 60, walk: 0, cooldown: 5 * 60, reps: 1))
}

/// `number` only drives the phase lookup below — the table keeps it as a
/// human-readable week index, but `TrainingWeek` itself doesn't store it.
private func week(_ number: Int, _ slot1: PlannedWorkout, _ slot2: PlannedWorkout, _ slot3: PlannedWorkout) -> TrainingWeek {
    TrainingWeek(workouts: [slot1, slot2, slot3], phase: phase(forWeek: number))
}

private func phase(forWeek number: Int) -> TrainingPhase {
    switch number {
    case 1...8: .base
    case 9...14: .development
    case 15...22: .long
    default: .races
    }
}

private func date(year: Int, month: Int, day: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
}

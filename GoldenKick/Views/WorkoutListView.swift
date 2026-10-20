import SwiftData
import SwiftUI

struct WorkoutListView: View {
    @Bindable var engine: WorkoutEngine
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [WorkoutRecord]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Личный тренер")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch TrainingPlan.status() {
        case .notStarted:
            ContentUnavailableView(
                "План начнётся в понедельник, 19 октября 2026",
                systemImage: "calendar"
            )
        case .finished:
            ContentUnavailableView(
                "План завершён. Полумарафон 18 апреля 2027 позади",
                systemImage: "flag.checkered"
            )
        case .active(let week):
            weekList(week)
        }
    }

    private func weekList(_ week: TrainingWeek) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Неделя \(week.number) · \(week.phase.title)")
                        .font(.title2.bold())
                    if week.isRecovery {
                        Text("Облегчённая неделя")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Тренировки") {
                ForEach(1...3, id: \.self) { slot in
                    slotRow(week: week, slot: slot)
                }
            }

            if allSlotsDone(week) {
                Section {
                    Label("Неделя выполнена", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)
                }
            }

            #if DEBUG
            Section {
                Toggle("Быстрый режим (1 мин = 5 с)", isOn: $engine.fastMode)
            } footer: {
                Text("Только в отладочной сборке. Тренировки в этом режиме не отмечаются выполненными.")
            }
            #endif
        }
    }

    private func slotRow(week: TrainingWeek, slot: Int) -> some View {
        let workout = week.workouts[slot - 1]
        let done = isDone(week: week.number, slot: slot)

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.headline)
                if let duration = workout.totalDuration {
                    Text("≈ \(TimeFormat.mmss(duration))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let race = workout.asRace {
                    Text(race.date.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if let race = workout.asRace {
                Button("Финишировал") {
                    finishRace(race, week: week.number, slot: slot)
                }
                .buttonStyle(.borderedProminent)
            } else if case .workout(let config) = workout {
                if slot == firstIncompleteSlot(week) {
                    Button("Начать") {
                        engine.start(config: config, planSlot: PlanSlot(week: week.number, slot: slot))
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Начать") {
                        engine.start(config: config, planSlot: PlanSlot(week: week.number, slot: slot))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func isDone(week: Int, slot: Int) -> Bool {
        records.contains { $0.planWeek == week && $0.planSlot == slot }
    }

    private func allSlotsDone(_ week: TrainingWeek) -> Bool {
        (1...3).allSatisfy { isDone(week: week.number, slot: $0) }
    }

    private func firstIncompleteSlot(_ week: TrainingWeek) -> Int? {
        (1...3).first { !isDone(week: week.number, slot: $0) }
    }

    /// Races aren't timed — finishing one just marks the slot done in history.
    private func finishRace(_ race: Race, week: Int, slot: Int) {
        let record = WorkoutRecord(
            startDate: .now,
            title: race.name,
            warmup: 0,
            run: 0,
            walk: 0,
            cooldown: 0,
            reps: 0,
            activeDuration: 0,
            runDuration: 0,
            planWeek: week,
            planSlot: slot
        )
        modelContext.insert(record)
        try? modelContext.save()
    }
}

#Preview {
    WorkoutListView(engine: WorkoutEngine(config: TrainingPlan.firstWorkoutConfig))
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}

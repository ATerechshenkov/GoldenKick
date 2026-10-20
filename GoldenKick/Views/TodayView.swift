import SwiftData
import SwiftUI

struct TodayView: View {
    @Bindable var engine: WorkoutEngine
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [WorkoutRecord]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Сегодня")
        }
    }

    @ViewBuilder
    private var content: some View {
        let progress = PlanProgress(records: records)
        switch TrainingPlan.status() {
        case .notStarted:
            List {
                RaceCountdownSection(progress: progress)
                Section {
                    Text("План начнётся в понедельник, 19 октября 2026")
                        .foregroundStyle(.secondary)
                }
                remindersAndDebugSections
            }
        case .finished:
            List {
                RaceCountdownSection(progress: progress)
                Section {
                    Text("План завершён. Полумарафон 18 апреля 2027 позади")
                        .foregroundStyle(.secondary)
                }
                remindersAndDebugSections
            }
        case .active(let week):
            weekList(week, progress: progress)
        }
    }

    private func weekList(_ week: TrainingWeek, progress: PlanProgress) -> some View {
        List {
            RaceCountdownSection(progress: progress)

            Section {
                mainCard(week: week, progress: progress)
            }

            Section {
                WeekStripView(week: week, progress: progress)
            }

            Section("Тренировки") {
                ForEach(1...3, id: \.self) { slot in
                    slotRow(week: week, slot: slot, progress: progress)
                }
            }

            remindersAndDebugSections
        }
    }

    @ViewBuilder
    private var remindersAndDebugSections: some View {
        RemindersSection()

        #if DEBUG
        Section {
            Toggle("Быстрый режим (1 мин = 5 с)", isOn: $engine.fastMode)
            Button("Тестовое напоминание через 5 с") {
                Task { await ReminderScheduler.sendTestNow(context: modelContext) }
            }
        } footer: {
            Text("Только в отладочной сборке. Тренировки в этом режиме не отмечаются выполненными.")
        }
        #endif
    }

    // MARK: - Main card: next unfinished workout, or the week's summary

    @ViewBuilder
    private func mainCard(week: TrainingWeek, progress: PlanProgress) -> some View {
        if let slot = progress.firstIncompleteSlot(in: week) {
            let workout = week.workouts[slot - 1]
            VStack(alignment: .leading, spacing: 10) {
                Text("Неделя \(week.number) · \(week.phase.title) · Тренировка \(slot) из 3")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(workout.title)
                    .font(.title2.bold())
                if let minutesText = workout.approxMinutesText {
                    Text(minutesText)
                        .foregroundStyle(.secondary)
                } else if let race = workout.asRace {
                    Text(race.date.formatted(date: .long, time: .omitted))
                        .foregroundStyle(.secondary)
                }

                if let race = workout.asRace {
                    Button("Финишировал") {
                        finishRace(race, week: week.number, slot: slot)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                } else if case .workout(let config) = workout {
                    Button("Начать") {
                        engine.start(config: config, planSlot: PlanSlot(week: week.number, slot: slot))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Неделя выполнена 💪")
                    .font(.title2.bold())
                if let next = PlanProgress.nextWeek(after: week) {
                    Text("Дальше: неделя \(next.number) · \(next.phase.title) · \(next.workouts[0].title)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Это была последняя неделя плана")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - This week's slots

    private func slotRow(week: TrainingWeek, slot: Int, progress: PlanProgress) -> some View {
        let workout = week.workouts[slot - 1]
        let done = progress.isDone(week: week.number, slot: slot)

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
                if slot == progress.firstIncompleteSlot(in: week) {
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
        Task { await ReminderScheduler.reschedule(context: modelContext) }
    }
}

#Preview {
    TodayView(engine: WorkoutEngine(config: TrainingPlan.firstWorkoutConfig))
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}

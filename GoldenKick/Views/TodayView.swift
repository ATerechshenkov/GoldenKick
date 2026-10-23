import SwiftData
import SwiftUI

struct TodayView: View {
    @Bindable var engine: WorkoutEngine
    @Environment(\.modelContext) private var modelContext
    @Query private var records: [WorkoutRecord]
    @State private var selectedDay: PlanDay?

    private var progress: PlanProgress { PlanProgress(records: records) }

    var body: some View {
        NavigationStack {
            List {
                mainCardSection
                Section {
                    PlanCalendarView(progress: progress) { day in
                        selectedDay = day
                    }
                }
                remindersAndDebugSections
            }
            .navigationTitle("Сегодня")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        GoalsView()
                    } label: {
                        Image(systemName: "star")
                    }
                }
            }
            .sheet(item: $selectedDay) { day in
                PlanDayDetailView(day: day, engine: engine, progress: progress)
            }
        }
    }

    // MARK: - Main card: nearest unfinished plan day

    @ViewBuilder
    private var mainCardSection: some View {
        Section {
            if let day = progress.nextIncomplete() {
                VStack(alignment: .leading, spacing: 10) {
                    if progress.isTodayDone() {
                        Text("Сегодняшняя тренировка выполнена ✓")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    Text("\(PlanText.relativeDay(day.date)) · \(PlanText.shortDate(day.date))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(day.workout.title)
                        .font(.title2.bold())
                    if let minutesText = day.workout.approxMinutesText {
                        Text(minutesText)
                            .foregroundStyle(.secondary)
                    }
                    actionButton(for: day)
                }
                .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("План завершён 💪")
                        .font(.title2.bold())
                    Text("Все тренировки плана выполнены")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func actionButton(for day: PlanDay) -> some View {
        let canStart = progress.canStart(day)
        if let race = day.workout.asRace {
            Button("Финишировал") { finishRace(race, day: day) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!canStart)
        } else if case .workout(let config) = day.workout {
            Button("Начать") { engine.start(config: config, planDate: day.date) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!canStart)
        }
    }

    // MARK: - Reminders & debug

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

    /// Races aren't timed — finishing one just records the day as done.
    private func finishRace(_ race: Race, day: PlanDay) {
        modelContext.insert(WorkoutRecord.raceFinish(race, planDate: day.date))
        try? modelContext.save()
        Task { await ReminderScheduler.reschedule(context: modelContext) }
    }
}

#Preview {
    TodayView(engine: WorkoutEngine(config: TrainingPlan.firstWorkoutConfig))
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}

import SwiftData
import SwiftUI

/// Sheet shown when tapping a plan day in the calendar: full detail for a
/// workout or a race/goal day.
struct PlanDayDetailView: View {
    let day: PlanDay
    @Bindable var engine: WorkoutEngine
    let progress: PlanProgress
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(PlanText.fullDate(day.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(day.workout.title)
                            .font(.title2.bold())

                        if let race = day.workout.asRace {
                            Text(PlanText.countdown(to: race.date))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(day.phase.title)
                                .foregroundStyle(.secondary)
                            if let minutesText = day.workout.approxMinutesText {
                                Text(minutesText)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let makeup = makeupRecord {
                            NavigationLink {
                                MakeupDayDetailView(record: makeup, showsClose: false)
                            } label: {
                                Text("\(PlanText.statusTitle(.madeUp)) · \(PlanText.shortDate(makeup.startDate))")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(statusColor)
                            }
                        } else {
                            Text(PlanText.statusTitle(progress.status(of: day)))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(statusColor)
                        }

                        if let record = progress.record(for: day), day.workout.asRace == nil {
                            Text("Активное время: \(TimeFormat.mmss(record.activeDuration))")
                                .foregroundStyle(.secondary)
                        }

                        actionButton
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Тренировка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var actionButton: some View {
        if progress.canStart(day) {
            if let race = day.workout.asRace {
                Button("Финишировал") { finishRace(race) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            } else if case .workout(let config) = day.workout {
                Button("Начать") { start(config: config) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
        } else if progress.status(of: day) == .missed, case .workout(let config) = day.workout {
            let blocker = progress.makeupBlocker(for: day)
            Button("Отработать") { start(config: config) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(blocker != nil)
            if let blocker {
                Text(PlanText.makeupBlockerText(blocker))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var makeupRecord: WorkoutRecord? {
        guard progress.status(of: day) == .madeUp else { return nil }
        return progress.record(for: day)
    }

    private var statusColor: Color {
        switch progress.status(of: day) {
        case .done, .madeUp: .green
        case .upcoming: .primary
        case .missed: .secondary
        }
    }

    private func start(config: WorkoutConfig) {
        dismiss()
        engine.start(config: config, planDate: day.date)
    }

    private func finishRace(_ race: Race) {
        modelContext.insert(WorkoutRecord.raceFinish(race, planDate: day.date))
        try? modelContext.save()
        Task { await ReminderScheduler.reschedule(context: modelContext) }
        dismiss()
    }
}

/// Detail for the day a missed workout was made up on.
struct MakeupDayDetailView: View {
    let record: WorkoutRecord
    /// `true` when shown as its own sheet rather than pushed from a plan day.
    let showsClose: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(PlanText.fullDate(record.startDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let planDate = record.planDate {
                        Text("Отработка тренировки за \(PlanText.shortDate(planDate))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    Text(record.title)
                        .font(.title2.bold())
                    Text("Активное время: \(TimeFormat.mmss(record.activeDuration))")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Тренировка")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsClose {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}

import SwiftData
import SwiftUI

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRecord.startDate, order: .reverse) private var records: [WorkoutRecord]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView("Пока нет завершённых тренировок", systemImage: "clock")
                } else {
                    List {
                        ForEach(records) { record in
                            row(for: record)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("История")
        }
    }

    private func row(for record: WorkoutRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let planDate = record.planDate, let day = TrainingPlan.workout(on: planDate) {
                Text("\(day.phase.title) · \(PlanText.shortDate(planDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(record.title)
                .font(.headline)
            if isRace(record) {
                Text("Финиш ✓")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                HStack {
                    Text("Активное время: \(TimeFormat.mmss(record.activeDuration))")
                    Spacer()
                    Text("Бег: \(TimeFormat.mmss(record.runDuration))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    /// Race days don't have a meaningful active/run duration to show.
    private func isRace(_ record: WorkoutRecord) -> Bool {
        guard let planDate = record.planDate else { return false }
        return TrainingPlan.workout(on: planDate)?.workout.asRace != nil
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(records[index])
        }
    }
}

#Preview {
    WorkoutHistoryView()
        .modelContainer(for: WorkoutRecord.self, inMemory: true)
}

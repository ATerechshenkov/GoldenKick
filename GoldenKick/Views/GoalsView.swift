import SwiftData
import SwiftUI

/// "Цели" screen: every race/goal in the plan, nearest upcoming first.
struct GoalsView: View {
    @Query private var records: [WorkoutRecord]

    private var progress: PlanProgress { PlanProgress(records: records) }

    private var orderedGoals: [PlanDay] {
        let today = Calendar.current.startOfDay(for: .now)
        let all = TrainingPlan.raceDays
        let upcoming = all.filter { $0.date >= today }.sorted { $0.date < $1.date }
        let past = all.filter { $0.date < today }.sorted { $0.date < $1.date }
        return upcoming + past
    }

    var body: some View {
        List(orderedGoals) { day in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.workout.title)
                        .font(.headline)
                    Text(PlanText.longDate(day.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(statusText(for: day))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor(for: day))
            }
            .padding(.vertical, 2)
        }
        .navigationTitle("Цели")
    }

    private func statusText(for day: PlanDay) -> String {
        switch progress.status(of: day) {
        case .done: "Выполнена ✓"
        case .missed: "Пропущена"
        case .upcoming: PlanText.countdown(to: day.date)
        }
    }

    private func statusColor(for day: PlanDay) -> Color {
        switch progress.status(of: day) {
        case .done: .green
        case .missed: .secondary
        case .upcoming: .primary
        }
    }
}

#Preview {
    NavigationStack {
        GoalsView()
    }
    .modelContainer(for: WorkoutRecord.self, inMemory: true)
}

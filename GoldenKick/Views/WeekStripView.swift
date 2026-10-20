import SwiftUI

/// Mon–Sun strip for the current plan week: a filled dot on days a slot was
/// completed, an outlined dot on recommended days (Tue/Thu/Sat) while slots
/// remain, and today's column highlighted. Order of completion doesn't
/// matter — slots belong to the week, not to a specific day.
struct WeekStripView: View {
    let week: TrainingWeek
    let progress: PlanProgress

    private static let dayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private static let recommendedIndices: Set<Int> = [1, 3, 5] // Tue, Thu, Sat

    var body: some View {
        let days = PlanProgress.days(of: week)
        let completedDays = progress.completionDays(in: week)
        let weekDone = progress.isWeekDone(week)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        HStack {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let isCompleted = completedDays.contains(day)
                let isRecommended = Self.recommendedIndices.contains(index) && !weekDone

                VStack(spacing: 6) {
                    Text(Self.dayLabels[index])
                        .font(.caption2)
                        .fontWeight(isToday ? .bold : .regular)
                        .foregroundStyle(isToday ? .primary : .secondary)

                    Circle()
                        .strokeBorder(isCompleted || isRecommended ? Color.orange : .clear, lineWidth: 2)
                        .background(Circle().fill(isCompleted ? Color.orange : .clear))
                        .frame(width: 14, height: 14)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isToday ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

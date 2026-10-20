import SwiftUI

/// Countdown to each race in the plan: days/weeks remaining, or the result
/// (finished/missed) once the date has passed. Upcoming races list first.
struct RaceCountdownSection: View {
    let progress: PlanProgress

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var orderedRaces: [RaceEntry] {
        let today = self.today
        let all = PlanProgress.raceSlots
        let upcoming = all.filter { $0.race.date >= today }.sorted { $0.race.date < $1.race.date }
        let past = all.filter { $0.race.date < today }.sorted { $0.race.date < $1.race.date }
        return upcoming + past
    }

    var body: some View {
        Section("Забеги") {
            ForEach(orderedRaces) { entry in
                HStack {
                    Text(entry.race.name)
                        .font(.subheadline)
                    Spacer()
                    Text(statusText(for: entry))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusColor(for: entry))
                }
            }
        }
    }

    private func daysUntil(_ entry: RaceEntry) -> Int {
        Calendar.current.dateComponents(
            [.day],
            from: today,
            to: Calendar.current.startOfDay(for: entry.race.date)
        ).day ?? 0
    }

    private func statusText(for entry: RaceEntry) -> String {
        let days = daysUntil(entry)
        guard days >= 0 else {
            return progress.raceFinished(entry.slot) ? "✓" : "Пропущен"
        }
        if days == 0 { return "Сегодня!" }
        if days <= 14 { return "через \(days) дн." }
        return "через \(days / 7) нед."
    }

    private func statusColor(for entry: RaceEntry) -> Color {
        let days = daysUntil(entry)
        guard days >= 0 else {
            return progress.raceFinished(entry.slot) ? .green : .secondary
        }
        return .primary
    }
}

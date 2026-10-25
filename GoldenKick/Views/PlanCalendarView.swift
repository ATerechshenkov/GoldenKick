import SwiftUI

/// A month grid over the training plan: filled/outlined squares encode each
/// day's status, with a star marker under race days. Swiping or the arrow
/// buttons change the month, bounded to the plan's date range.
struct PlanCalendarView: View {
    let progress: PlanProgress
    var onSelect: (PlanDay) -> Void
    var onSelectMakeup: (WorkoutRecord) -> Void

    @State private var displayedMonth = clampMonth(monthStart(.now))
    /// +1 when the last navigation moved forward, -1 when backward — picks
    /// which way the month slides in/out.
    @State private var navigationDirection = 1

    private let calendar = Calendar.current
    private static let weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            monthGrid
                .id(displayedMonth)
                .transition(monthTransition)
                .clipped()
                .simultaneousGesture(swipeGesture)
            controls
        }
        .padding(.vertical, 4)
    }

    private var monthGrid: some View {
        VStack(spacing: 12) {
            Text(monthTitle)
                .font(.headline)
            weekdayRow
            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(gridDays, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
    }

    private var monthTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: navigationDirection >= 0 ? .trailing : .leading),
            removal: .move(edge: navigationDirection >= 0 ? .leading : .trailing)
        )
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(Self.weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var controls: some View {
        HStack {
            if !calendar.isDate(displayedMonth, equalTo: Self.monthStart(.now), toGranularity: .month) {
                Button("Сегодня") {
                    let target = Self.clampMonth(Self.monthStart(.now))
                    navigationDirection = target >= displayedMonth ? 1 : -1
                    withAnimation { displayedMonth = target }
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
            }
            Spacer()
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(!canChangeMonth(by: -1))

            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(!canChangeMonth(by: 1))
        }
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let day = TrainingPlan.workout(on: date)
        let isCurrentMonth = calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(date)
        // A make-up day has no plan day of its own and looks like a done one.
        let makeup = day == nil ? progress.makeupRecord(on: date) : nil
        let status = day.map { progress.status(of: $0) } ?? (makeup == nil ? nil : .done)

        Button {
            if let day {
                onSelect(day)
            } else if let makeup {
                onSelectMakeup(makeup)
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.body)
                    .foregroundStyle(textColor(status: status, isCurrentMonth: isCurrentMonth))
                    .frame(width: 32, height: 32)
                    .background(squareBackground(status: status))
                    .overlay(todayRing(isToday: isToday))
                raceMarker(day: day, status: status)
            }
        }
        .buttonStyle(.plain)
        .disabled(day == nil && makeup == nil)
        .frame(maxWidth: .infinity)
        .opacity(isCurrentMonth ? 1 : 0.35)
    }

    @ViewBuilder
    private func squareBackground(status: PlanDayStatus?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        switch status {
        case .done: shape.fill(Color.accentColor)
        case .upcoming: shape.strokeBorder(Color.accentColor, lineWidth: 2)
        case .missed: shape.fill(Color(.systemGray4))
        case .madeUp:
            shape.fill(Color(.systemGray4))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .padding(3)
                }
        case nil: EmptyView()
        }
    }

    @ViewBuilder
    private func todayRing(isToday: Bool) -> some View {
        if isToday {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary, lineWidth: 1.5)
                .padding(-3)
        }
    }

    @ViewBuilder
    private func raceMarker(day: PlanDay?, status: PlanDayStatus?) -> some View {
        if let day, day.workout.asRace != nil {
            switch status {
            case .done: Image(systemName: "star.fill").foregroundStyle(Color.accentColor)
            case .upcoming: Image(systemName: "star").foregroundStyle(Color.accentColor)
            default: Image(systemName: "star").foregroundStyle(.secondary)
            }
        } else {
            Image(systemName: "star").opacity(0)
        }
    }

    private func textColor(status: PlanDayStatus?, isCurrentMonth: Bool) -> Color {
        guard status == .done else { return isCurrentMonth ? .primary : .secondary }
        return .black
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        let raw = formatter.string(from: displayedMonth)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    /// 35 dates (5 Mon...Sun weeks) covering the displayed month.
    private var gridDays: [Date] {
        let weekday = calendar.component(.weekday, from: displayedMonth) // 1 = Sun ... 7 = Sat
        let mondayOffset = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -mondayOffset, to: displayedMonth)!
        return (0..<35).map { calendar.date(byAdding: .day, value: $0, to: gridStart)! }
    }

    // MARK: - Month navigation

    private func changeMonth(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        let clamped = Self.clampMonth(next)
        guard clamped != displayedMonth else { return }
        navigationDirection = delta >= 0 ? 1 : -1
        withAnimation { displayedMonth = clamped }
    }

    private func canChangeMonth(by delta: Int) -> Bool {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return false }
        return Self.clampMonth(next) != displayedMonth
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 50, abs(dx) > abs(dy) else { return }
                changeMonth(by: dx < 0 ? 1 : -1)
            }
    }

    private static func monthStart(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    private static func clampMonth(_ date: Date) -> Date {
        let start = monthStart(TrainingPlan.startDate)
        let end = monthStart(TrainingPlan.endDate)
        return min(max(date, start), end)
    }
}

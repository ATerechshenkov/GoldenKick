import Foundation
import SwiftData
import UserNotifications

/// Schedules local notifications for the next 14 days: morning reminders on
/// unfinished plan workout days, and race-day / race-eve notifications. No
/// server — everything is computed from `TrainingPlan` and the current
/// `WorkoutRecord`s.
@MainActor
enum ReminderScheduler {
    static let enabledKey = "remindersEnabled"
    static let minutesKey = "reminderMinutesSinceMidnight"
    static let defaultMinutes = 6 * 60 + 30 // 06:30

    private static let idPrefix = "reminder-"

    /// Requests notification permission. Call only when the person turns the
    /// toggle on, never at launch.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func isAuthorizationDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    static func storedMinutes() -> Int {
        (UserDefaults.standard.object(forKey: minutesKey) as? Int) ?? defaultMinutes
    }

    /// Clears and recomputes all pending reminders. Safe to call anytime —
    /// if reminders are off, this only clears old ones.
    static func reschedule(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ourIDs = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ourIDs)

        guard UserDefaults.standard.bool(forKey: enabledKey) else { return }

        let records = (try? context.fetch(FetchDescriptor<WorkoutRecord>())) ?? []
        let progress = PlanProgress(records: records)
        let now = Date()

        for (fireDate, body) in plannedReminders(from: now, progress: progress, minutesSinceMidnight: storedMinutes()) {
            let content = UNMutableNotificationContent()
            content.title = "GoldenKick"
            content.body = body
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: idPrefix + isoDay(fireDate), content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    // MARK: - Pure scheduling logic (testable without UNUserNotificationCenter)

    /// Computes (fire date, notification text) pairs for the next 14 days,
    /// skipping moments that have already passed.
    static func plannedReminders(from now: Date, progress: PlanProgress, minutesSinceMidnight: Int) -> [(Date, String)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var results: [(Date, String)] = []

        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(byAdding: .minute, value: minutesSinceMidnight, to: day),
                  fire > now,
                  let body = reminderBody(for: day, progress: progress)
            else { continue }
            results.append((fire, body))
        }
        return results
    }

    /// Resolves what a notification on this calendar day should say, if any.
    /// Order matters: race day, then race eve, then the regular plan-day check.
    static func reminderBody(for day: Date, progress: PlanProgress) -> String? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)

        if let race = TrainingPlan.raceDays.first(where: { $0.date == dayStart })?.workout.asRace {
            return "Сегодня \(race.name)! Удачи 🏁"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart),
           let race = TrainingPlan.raceDays.first(where: { $0.date == tomorrow })?.workout.asRace {
            return "Завтра \(race.name). Сегодня отдых — выспись и подготовь форму 🏁"
        }

        // The race-day/eve notifications above already cover race days, so
        // only a timed workout that isn't done yet gets the morning reminder.
        guard let planDay = TrainingPlan.workout(on: dayStart),
              case .workout = planDay.workout,
              progress.record(for: planDay) == nil,
              let minutesText = planDay.workout.approxMinutesText
        else { return nil }
        return "Доброе утро! Сегодня: \(planDay.workout.title), \(minutesText)"
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

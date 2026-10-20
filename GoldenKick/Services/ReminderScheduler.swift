import Foundation
import SwiftData
import UserNotifications

/// Schedules local notifications for the next 14 days: Tue/Thu/Sat morning
/// reminders about the next unfinished workout, and race-day / race-eve
/// notifications. No server — everything is computed from `TrainingPlan` and
/// the current `WorkoutRecord`s.
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

    #if DEBUG
    /// Fires the same "next workout" reminder 5 seconds from now, for debugging.
    static func sendTestNow(context: ModelContext) async {
        let records = (try? context.fetch(FetchDescriptor<WorkoutRecord>())) ?? []
        let progress = PlanProgress(records: records)
        let body = reminderBody(for: Date(), progress: progress) ?? "Доброе утро! Самое время размяться 🏃"

        let content = UNMutableNotificationContent()
        content.title = "GoldenKick"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "reminder-test", content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
    #endif

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
    /// Order matters: race day, then race eve, then the regular Tue/Thu/Sat check.
    static func reminderBody(for day: Date, progress: PlanProgress) -> String? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)

        if let race = PlanProgress.raceSlots.first(where: { calendar.isDate($0.race.date, inSameDayAs: dayStart) })?.race {
            return "Сегодня \(race.name)! Удачи 🏁"
        }

        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart),
           let race = PlanProgress.raceSlots.first(where: { calendar.isDate($0.race.date, inSameDayAs: tomorrow) })?.race {
            return "Завтра \(race.name). Сегодня отдых — выспись и подготовь форму 🏁"
        }

        let weekday = calendar.component(.weekday, from: dayStart) // 1 = Sun ... 7 = Sat
        guard [3, 5, 7].contains(weekday) else { return nil } // Tue, Thu, Sat
        guard case .active(let week) = TrainingPlan.status(on: dayStart) else { return nil }
        guard let slot = progress.firstIncompleteSlot(in: week) else { return nil }

        let workout = week.workouts[slot - 1]
        // The next slot is a race, not a timed workout — the race-day/eve
        // notifications above already cover it.
        guard case .workout = workout, let minutesText = workout.approxMinutesText else { return nil }
        return "Доброе утро! Сегодня: \(workout.title), \(minutesText)"
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}

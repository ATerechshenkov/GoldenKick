//
//  GoldenKickApp.swift
//  GoldenKick
//
//  Created by Andrey on 08.10.2026.
//

import SwiftData
import SwiftUI
import UserNotifications

@main
struct GoldenKickApp: App {
    @State private var engine = WorkoutEngine(config: TrainingPlan.firstWorkoutConfig)
    private let notificationDelegate = ReminderNotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        // No workout can be running at launch, so any surviving activity is a leftover.
        LiveActivityService.endAll()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(engine: engine)
        }
        .modelContainer(for: WorkoutRecord.self)
    }
}

/// Without this, a local notification that fires while the app is in the
/// foreground is silently dropped instead of shown as a banner.
private final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

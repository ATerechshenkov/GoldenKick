import ActivityKit
import Foundation
import os
import UIKit

/// Drives the workout's Live Activity. All calls are no-ops when Live Activities
/// are disabled or unavailable, so the workout itself never depends on this succeeding.
@MainActor
final class LiveActivityService {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "GoldenKick",
        category: "LiveActivity"
    )

    private var activity: Activity<WorkoutActivityAttributes>?
    /// Tail of the operation chain: updates and the final end run strictly in order,
    /// so a late `update` can never overtake (or resurrect) an `end`.
    private var queue: Task<Void, Never>?

    func start(title: String, state: WorkoutActivityAttributes.ContentState) {
        // Clean up anything left over from a previous workout before starting a new one.
        Self.endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.logger.notice("start skipped: Live Activities disabled")
            return
        }
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let content = ActivityContent(state: state, staleDate: nil)
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            Self.logger.notice("start ok")
        } catch {
            Self.logger.error("start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState, reason: String) {
        guard let activity else {
            Self.logger.notice("update skipped (no activity): \(reason, privacy: .public)")
            return
        }
        let content = ActivityContent(state: state, staleDate: nil)
        enqueue { [logger = Self.logger] in
            logger.notice("update begin: \(reason, privacy: .public)")
            await activity.update(content)
            logger.notice("update done: \(reason, privacy: .public), state=\(String(describing: activity.activityState), privacy: .public)")
        }
    }

    /// Ends the activity. `dismissAt == nil` removes it immediately; otherwise the final
    /// state stays on the lock screen until that date.
    func end(_ state: WorkoutActivityAttributes.ContentState, dismissAt: Date?) {
        guard let activity else { return }
        self.activity = nil
        let content = ActivityContent(state: state, staleDate: nil)
        let policy: ActivityUIDismissalPolicy = dismissAt.map { .after($0) } ?? .immediate
        enqueue { [logger = Self.logger] in
            logger.notice("end begin: immediate=\(dismissAt == nil)")
            await activity.end(content, dismissalPolicy: policy)
            logger.notice("end done: state=\(String(describing: activity.activityState), privacy: .public)")
        }
    }

    /// Ends every Live Activity of this app, e.g. ones orphaned by a force-quit.
    static func endAll() {
        for stale in Activity<WorkoutActivityAttributes>.activities {
            logger.notice("ending stale activity \(stale.id, privacy: .public)")
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Runs `operation` after all earlier ones, under a background-task assertion so the
    /// process isn't suspended before the ActivityKit call completes.
    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            let id = UIApplication.shared.beginBackgroundTask(withName: "LiveActivity")
            await operation()
            if id != .invalid {
                UIApplication.shared.endBackgroundTask(id)
            }
        }
    }
}

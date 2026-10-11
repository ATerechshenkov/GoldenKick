import ActivityKit

/// Drives the workout's Live Activity. All calls are no-ops when Live Activities
/// are disabled or unavailable, so the workout itself never depends on this succeeding.
@MainActor
final class LiveActivityService {
    private var activity: Activity<WorkoutActivityAttributes>?

    func start(title: String, state: WorkoutActivityAttributes.ContentState) {
        // Clean up anything orphaned by a previous force-quit before starting a new one.
        for stale in Activity<WorkoutActivityAttributes>.activities {
            Task { await stale.end(nil, dismissalPolicy: .immediate) }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        let content = ActivityContent(state: state, staleDate: state.segmentEnd?.addingTimeInterval(60))
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        let content = ActivityContent(state: state, staleDate: state.segmentEnd?.addingTimeInterval(60))
        Task { await activity.update(content) }
    }

    func end(_ state: WorkoutActivityAttributes.ContentState, immediately: Bool) {
        guard let activity else { return }
        self.activity = nil
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity.end(content, dismissalPolicy: immediately ? .immediate : .default) }
    }
}

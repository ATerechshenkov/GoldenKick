import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(context.state.kind.color)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.kind.title)
                            .font(.headline)
                    } icon: {
                        Image(systemName: context.state.kind.symbolName)
                    }
                    .foregroundStyle(context.state.kind.color)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownView(state: context.state)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let intervalText = context.state.intervalText {
                            Text(intervalText)
                                .font(.subheadline)
                        }
                        Text(context.state.nextText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressBar(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.kind.symbolName)
                    .foregroundStyle(context.state.kind.color)
            } compactTrailing: {
                CountdownView(state: context.state)
                    .font(.caption.monospacedDigit().bold())
                    .frame(width: 44)
            } minimal: {
                Image(systemName: context.state.kind.symbolName)
                    .foregroundStyle(context.state.kind.color)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(state.isFinished ? "ТРЕНИРОВКА ЗАВЕРШЕНА" : state.kind.title)
                    .font(.system(size: 28, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                if !state.isFinished {
                    CountdownView(state: state)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }

            if state.isPaused {
                Text("ПАУЗА")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.25), in: Capsule())
            }

            if let intervalText = state.intervalText {
                Text(intervalText)
                    .font(.subheadline)
            }

            if !state.isFinished {
                Text(state.nextText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressBar(state: state)
        }
        .padding()
        .foregroundStyle(.white)
    }
}

/// Live countdown driven by the system while running; a frozen value while paused.
private struct CountdownView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.isFinished {
            EmptyView()
        } else if let end = state.segmentEnd {
            Text(timerInterval: Date()...max(end, Date()), countsDown: true)
        } else {
            Text(TimeFormat.mmss(state.pausedRemaining))
        }
    }
}

/// Overall workout progress: advances on its own while running, frozen while paused.
private struct ProgressBar: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if !state.isPaused, !state.isFinished, state.workoutEnd > state.workoutStart {
            ProgressView(timerInterval: state.workoutStart...state.workoutEnd, countsDown: false)
                .tint(.white)
        } else {
            ProgressView(value: state.progress)
                .tint(.white)
        }
    }
}

#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes(workoutTitle: "Бег 1:00 / шаг 2:00 × 6")) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(
        kind: .run,
        segmentEnd: Date().addingTimeInterval(45),
        pausedRemaining: 45,
        workoutStart: Date().addingTimeInterval(-300),
        workoutEnd: Date().addingTimeInterval(900),
        progress: 0.25,
        intervalText: "Интервал 3 из 6",
        nextText: "Дальше: шаг 2:00",
        isPaused: false,
        isFinished: false
    )
}

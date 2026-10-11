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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            // Reserved even when empty so the region's height doesn't change between phases.
                            Text(context.state.intervalText ?? " ")
                                .font(.subheadline)
                                .opacity(context.state.intervalText == nil ? 0 : 1)

                            Spacer(minLength: 8)

                            Text(context.state.isFinished ? summaryText(for: context.state) : context.state.nextText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ProgressBar(state: context.state)
                    }
                    .padding(.horizontal, 4)
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

/// Total elapsed workout time once finished: `workoutStart...workoutEnd` collapses to this span
/// as soon as `totalRemaining` hits zero, so no separate stored field is needed.
private func summaryText(for state: WorkoutActivityAttributes.ContentState) -> String {
    "Итого: \(TimeFormat.mmss(state.workoutEnd.timeIntervalSince(state.workoutStart)))"
}

/// Every row below is always present (reserved via `opacity`/placeholder text when not applicable)
/// so the card's layout and height stay fixed across all phases, pause, and the finished state —
/// nothing should reflow or resize while the Live Activity is running.
private struct LockScreenView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                CountdownView(state: state)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 92, alignment: .leading)

                Spacer(minLength: 8)

                Text(state.isFinished ? "ТРЕНИРОВКА ЗАВЕРШЕНА" : state.kind.title)
                    .font(.system(size: 26, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.trailing)
            }

            Text("ПАУЗА")
                .font(.subheadline.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(.white.opacity(0.25), in: Capsule())
                .opacity(state.isPaused ? 1 : 0)

            HStack {
                Text(state.intervalText ?? " ")
                    .font(.subheadline)
                    .opacity(state.intervalText == nil ? 0 : 1)

                Spacer(minLength: 8)

                Text(state.isFinished ? summaryText(for: state) : state.nextText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressBar(state: state)
        }
        .padding(20)
        .foregroundStyle(.white)
    }
}

/// Live countdown driven by the system while running; a frozen value while paused;
/// pinned to "0:00" once finished, rather than disappearing.
private struct CountdownView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.isFinished {
            Text(TimeFormat.mmss(0))
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

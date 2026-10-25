import ActivityKit
import WidgetKit
import SwiftUI

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(title: title(for: context), state: context.state)
                .activityBackgroundTint(.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.run")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TotalTimeView(state: context.state)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SegmentedProgressBar(state: context.state, height: 9)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
            } compactTrailing: {
                TotalTimeView(state: context.state)
                    .font(.caption.monospacedDigit().bold())
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "figure.run")
            }
        }
    }
}

private func title(for context: ActivityViewContext<WorkoutActivityAttributes>) -> String {
    context.state.isFinished ? "ТРЕНИРОВКА ЗАВЕРШЕНА" : context.attributes.workoutTitle
}

/// Nothing here depends on content updates while running: total time and the progress
/// overlay are driven by the system's timers, the segment strip is static.
private struct LockScreenView: View {
    let title: String
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                TotalTimeView(state: state)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 84, alignment: .leading)

                Spacer(minLength: 8)

                Text(state.isPaused ? "ПАУЗА" : title)
                    .font(.system(size: 18, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.trailing)
            }

            SegmentedProgressBar(state: state, height: 9)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
    }
}

/// Whole-workout time: a live countdown driven by the system while running, a frozen
/// value while paused, and the total elapsed time once finished.
private struct TotalTimeView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if state.isFinished {
            Text(TimeFormat.mmss(state.workoutEnd.timeIntervalSince(state.workoutStart)))
        } else if state.isPaused {
            Text(TimeFormat.mmss(state.pausedTotalRemaining))
        } else {
            Text(timerInterval: Date()...max(state.workoutEnd, Date()), countsDown: true)
        }
    }
}

/// A fat bar of the whole workout: one coloured block per segment (run orange, walk green,
/// warm-up/cool-down blue), with the part already done darkened by the system-driven
/// progress view laid on top, so the bright part is what's still ahead.
private struct SegmentedProgressBar: View {
    let state: WorkoutActivityAttributes.ContentState
    let height: CGFloat

    private let spacing: CGFloat = 2

    var body: some View {
        ZStack {
            blocks
            progressOverlay
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 3))
    }

    private var blocks: some View {
        GeometryReader { geometry in
            let usable = geometry.size.width - spacing * CGFloat(max(state.blocks.count - 1, 0))
            HStack(spacing: spacing) {
                ForEach(Array(state.blocks.enumerated()), id: \.offset) { _, block in
                    Rectangle()
                        .fill(block.kind.color)
                        .frame(width: usable * block.fraction)
                }
            }
        }
    }

    /// The system's own progress view, stretched to the bar's height (its natural height is
    /// about 4 pt). Its filled part is a translucent black, which dims the blocks already passed.
    /// It must not be masked: a mask is sized to the unscaled view and cuts the dimming short.
    @ViewBuilder
    private var progressOverlay: some View {
        if !state.isPaused, !state.isFinished, state.workoutEnd > state.workoutStart {
            ProgressView(timerInterval: state.workoutStart...state.workoutEnd, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.black.opacity(0.55))
            .scaleEffect(x: 1, y: height / 4)
        } else {
            ProgressView(value: state.isFinished ? 1 : state.progress)
                .tint(.black.opacity(0.55))
                .scaleEffect(x: 1, y: height / 4)
        }
    }
}

#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes(workoutTitle: "Бег 1 мин / шаг 2 мин × 6")) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(
        blocks: [
            .init(kind: .warmup, fraction: 0.2),
            .init(kind: .run, fraction: 0.1),
            .init(kind: .walk, fraction: 0.2),
            .init(kind: .run, fraction: 0.1),
            .init(kind: .walk, fraction: 0.2),
            .init(kind: .cooldown, fraction: 0.2)
        ],
        workoutStart: Date().addingTimeInterval(-300),
        workoutEnd: Date().addingTimeInterval(900),
        pausedTotalRemaining: 900,
        progress: 0.25,
        isPaused: false,
        isFinished: false
    )
}

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class WorkoutEngine {
    enum Phase { case idle, running, paused, finished }

    let config: WorkoutConfig
    let segments: [Segment]

    /// Debug: 1 minute = 5 seconds. Applied when the workout starts.
    var fastMode = false

    private(set) var phase: Phase = .idle
    private(set) var currentIndex = 0
    /// Real seconds left in the current segment.
    private(set) var remaining: TimeInterval = 0
    /// Real seconds left in the whole workout.
    private(set) var totalRemaining: TimeInterval = 0
    /// Real seconds of workout time (pauses excluded), shown on the finish screen.
    private(set) var elapsedActive: TimeInterval = 0
    private(set) var timeScale: Double = 1
    /// Wall-clock time the workout was started, for the history record.
    private(set) var startDate: Date?

    /// Injectable clock, so the catch-up logic can be exercised without waiting.
    @ObservationIgnored var now: () -> Date = { Date() }
    /// Called once, when the workout finishes naturally (not on manual stop).
    @ObservationIgnored var onFinish: (() -> Void)?

    @ObservationIgnored private var segmentEndDate: Date?
    @ObservationIgnored private var pausedRemaining: TimeInterval = 0
    @ObservationIgnored private var beepsPlayed = false
    @ObservationIgnored private var pendingAudioShutdown = false
    @ObservationIgnored private var lastAudioCheck = Date.distantPast
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let speech = SpeechService()
    @ObservationIgnored private let audio = AudioSessionKeeper()
    @ObservationIgnored private let liveActivity = LiveActivityService()

    init(config: WorkoutConfig) {
        self.config = config
        self.segments = config.makeSegments()
        speech.onIdle = { [weak self] in self?.shutdownAudioIfPending() }
        audio.onInterruptionEnded = { [weak self] in self?.reannounceAfterInterruption() }
    }

    // MARK: - Derived values

    var currentSegment: Segment { segments[currentIndex] }

    var nextSegment: Segment? {
        currentIndex + 1 < segments.count ? segments[currentIndex + 1] : nil
    }

    var totalRealDuration: TimeInterval { segments.reduce(0) { $0 + realDuration($1) } }

    /// Total time spent running across all intervals (nominal, not time-scaled).
    var runDuration: TimeInterval {
        segments.filter { $0.kind.activity == .run }.reduce(0) { $0 + $1.duration }
    }

    var progress: Double {
        guard totalRealDuration > 0 else { return 0 }
        return min(1, max(0, 1 - totalRemaining / totalRealDuration))
    }

    func realDuration(_ segment: Segment) -> TimeInterval {
        segment.duration * timeScale
    }

    /// Lead time for the countdown beeps before a phase change.
    private let beepLead: TimeInterval = 3

    // MARK: - Controls

    func start() {
        guard phase == .idle || phase == .finished else { return }
        timeScale = fastMode ? 5.0 / 60.0 : 1
        currentIndex = 0
        beepsPlayed = false
        pendingAudioShutdown = false
        UIApplication.shared.isIdleTimerDisabled = true
        audio.start()

        let t = now()
        startDate = t
        segmentEndDate = t.addingTimeInterval(realDuration(segments[0]))
        phase = .running
        speech.speak("Начинаем. " + announcement(for: segments[0]), interrupt: true)
        updateDisplay(at: t)
        liveActivity.start(title: config.title, state: makeActivityState(at: t))
        startTicking()
    }

    func pause() {
        guard phase == .running, let end = segmentEndDate else { return }
        pausedRemaining = max(0, end.timeIntervalSince(now()))
        segmentEndDate = nil
        remaining = pausedRemaining
        phase = .paused
        audio.stopBeeps()
        speech.speak("Пауза")
        liveActivity.update(makeActivityState(at: now()))
    }

    func resume() {
        guard phase == .paused else { return }
        let t = now()
        segmentEndDate = t.addingTimeInterval(pausedRemaining)
        phase = .running
        speech.speak("Продолжаем")
        updateDisplay(at: t)
        liveActivity.update(makeActivityState(at: t))
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        segmentEndDate = nil
        pendingAudioShutdown = false
        speech.stop()
        audio.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        phase = .idle
        liveActivity.end(makeActivityState(at: now()), immediately: true)
    }

    func reset() {
        guard phase == .finished else { return }
        phase = .idle
    }

    // MARK: - Ticking

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                self.tick()
            }
        }
    }

    /// Advances by wall-clock time. If the app woke up late, skips all elapsed segments
    /// and announces only the current one.
    func tick() {
        guard phase == .running, var end = segmentEndDate else { return }
        let t = now()
        let startIndex = currentIndex

        while t >= end {
            if currentIndex == segments.count - 1 {
                finish()
                return
            }
            currentIndex += 1
            // Chain from the previous end date, not from `t`, so lateness doesn't accumulate.
            end = end.addingTimeInterval(realDuration(segments[currentIndex]))
        }
        segmentEndDate = end

        if currentIndex != startIndex {
            beepsPlayed = false
            speech.speak(announcement(for: currentSegment), interrupt: true)
            liveActivity.update(makeActivityState(at: t))
        }

        let left = end.timeIntervalSince(t)
        if !beepsPlayed, left <= beepLead {
            beepsPlayed = true
            // Beeps that start too late (app woke up late) are worse than none.
            if left > 2.5 {
                audio.playCountdownBeeps()
            }
        }

        updateDisplay(at: t)

        if t.timeIntervalSince(lastAudioCheck) >= 5 {
            lastAudioCheck = t
            audio.ensureRunning()
        }
    }

    private func finish() {
        tickTask?.cancel()
        tickTask = nil
        segmentEndDate = nil
        currentIndex = segments.count - 1
        remaining = 0
        totalRemaining = 0
        elapsedActive = totalRealDuration
        phase = .finished
        UIApplication.shared.isIdleTimerDisabled = false

        pendingAudioShutdown = true
        speech.speak("Тренировка завершена. Отличная работа.")
        liveActivity.end(makeActivityState(at: now()), immediately: false)
        onFinish?()
        // Fallback in case the synthesizer never reports completion.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            self?.shutdownAudioIfPending()
        }
    }

    private func shutdownAudioIfPending() {
        guard pendingAudioShutdown else { return }
        pendingAudioShutdown = false
        audio.stop()
    }

    private func reannounceAfterInterruption() {
        guard phase == .running else { return }
        let before = currentIndex
        tick()
        if phase == .running && currentIndex == before {
            speech.speak(announcement(for: currentSegment), interrupt: true)
        }
    }

    private func updateDisplay(at t: Date) {
        guard let end = segmentEndDate else { return }
        remaining = max(0, end.timeIntervalSince(t))
        let rest = segments[(currentIndex + 1)...].reduce(0) { $0 + realDuration($1) }
        totalRemaining = remaining + rest
        elapsedActive = totalRealDuration - totalRemaining
    }

    // MARK: - Live Activity

    private func makeActivityState(at t: Date) -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            kind: currentSegment.kind,
            segmentEnd: segmentEndDate,
            pausedRemaining: phase == .paused ? pausedRemaining : remaining,
            workoutStart: t.addingTimeInterval(-elapsedActive),
            workoutEnd: t.addingTimeInterval(totalRemaining),
            progress: progress,
            intervalText: currentSegment.repIndex.map { "Интервал \($0) из \(config.reps)" },
            nextText: nextSegment.map { "Дальше: \($0.kind.nextTitle) \(TimeFormat.mmss(realDuration($0)))" } ?? "Последний отрезок",
            isPaused: phase == .paused,
            isFinished: phase == .finished
        )
    }

    // MARK: - Phrases

    func announcement(for segment: Segment) -> String {
        let duration = RussianNumerals.duration(segment.duration)
        let interval = intervalPhrase(for: segment).map { "\($0) " } ?? ""
        switch segment.kind {
        case .warmup:
            return "Разминка шагом, \(duration)."
        case .run:
            return "\(interval)Бег. \(duration.capitalizedFirst)."
        case .walk:
            return "\(interval)Шаг. \(duration.capitalizedFirst)."
        case .cooldown:
            return "Заминка шагом, \(duration)."
        }
    }

    /// Spoken once, at the start of each run/walk interval: a countdown of how many
    /// intervals remain, so the number isn't repeated on every segment within it.
    private func intervalPhrase(for segment: Segment) -> String? {
        guard let rep = segment.repIndex else { return nil }
        if segment.id > 0, segments[segment.id - 1].repIndex == rep { return nil }

        let reps = config.reps
        if rep == reps {
            return "Последний интервал."
        }
        if rep == 1 {
            let noun = RussianNumerals.plural(reps, one: "интервал", few: "интервала", many: "интервалов")
            return "\(RussianNumerals.cardinal(reps).capitalizedFirst) \(noun)."
        }
        let left = reps - rep + 1
        let noun = RussianNumerals.plural(left, one: "интервал", few: "интервала", many: "интервалов")
        return "Осталось \(RussianNumerals.cardinal(left)) \(noun)."
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

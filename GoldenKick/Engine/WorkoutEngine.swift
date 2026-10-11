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

    /// Injectable clock, so the catch-up logic can be exercised without waiting.
    @ObservationIgnored var now: () -> Date = { Date() }

    @ObservationIgnored private var segmentEndDate: Date?
    @ObservationIgnored private var pausedRemaining: TimeInterval = 0
    @ObservationIgnored private var warningSpoken = false
    @ObservationIgnored private var pendingAudioShutdown = false
    @ObservationIgnored private var lastAudioCheck = Date.distantPast
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private let speech = SpeechService()
    @ObservationIgnored private let audio = AudioSessionKeeper()

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

    var progress: Double {
        guard totalRealDuration > 0 else { return 0 }
        return min(1, max(0, 1 - totalRemaining / totalRealDuration))
    }

    func realDuration(_ segment: Segment) -> TimeInterval {
        segment.duration * timeScale
    }

    private var warningLead: TimeInterval { timeScale < 1 ? 3 : 10 }

    // MARK: - Controls

    func start() {
        guard phase == .idle || phase == .finished else { return }
        timeScale = fastMode ? 5.0 / 60.0 : 1
        currentIndex = 0
        warningSpoken = false
        pendingAudioShutdown = false
        UIApplication.shared.isIdleTimerDisabled = true
        audio.start()

        let t = now()
        segmentEndDate = t.addingTimeInterval(realDuration(segments[0]))
        phase = .running
        speech.speak("Начинаем. " + announcement(for: segments[0]), interrupt: true)
        updateDisplay(at: t)
        startTicking()
    }

    func pause() {
        guard phase == .running, let end = segmentEndDate else { return }
        pausedRemaining = max(0, end.timeIntervalSince(now()))
        segmentEndDate = nil
        remaining = pausedRemaining
        phase = .paused
        speech.speak("Пауза")
    }

    func resume() {
        guard phase == .paused else { return }
        let t = now()
        segmentEndDate = t.addingTimeInterval(pausedRemaining)
        phase = .running
        speech.speak("Продолжаем")
        updateDisplay(at: t)
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
            warningSpoken = false
            speech.speak(announcement(for: currentSegment), interrupt: true)
        }

        let left = end.timeIntervalSince(t)
        if !warningSpoken, let next = nextSegment, left <= warningLead {
            warningSpoken = true
            // A warning that comes too late (app woke up late) is worse than none.
            if left > warningLead - 3 {
                speech.speak("Через десять секунд — \(next.kind.nextTitle)")
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

    // MARK: - Phrases

    func announcement(for segment: Segment) -> String {
        let duration = RussianNumerals.duration(segment.duration)
        switch segment.kind {
        case .warmup:
            return "Разминка шагом, \(duration)."
        case .run:
            let rep = segment.repIndex ?? 1
            let reps = "Повтор \(RussianNumerals.cardinal(rep)) из \(RussianNumerals.genitive(config.reps))."
            return "Бег. \(reps) \(duration.capitalizedFirst)."
        case .walk:
            return "Шаг. \(duration.capitalizedFirst)."
        case .cooldown:
            return "Заминка шагом, \(duration)."
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

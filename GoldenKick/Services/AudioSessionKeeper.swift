import AVFoundation
import os

private let log = Logger(subsystem: "GoldenKick", category: "Audio")

/// Keeps the app alive in the background during a workout: an active `.playback` session
/// plus a continuously looping silent buffer, restarted after interruptions and route changes.
final class AudioSessionKeeper {
    private let session = AVAudioSession.sharedInstance()
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var silence: AVAudioPCMBuffer?
    private(set) var isActive = false

    /// Called after a phone call (or other interruption) ends and audio has been restored.
    var onInterruptionEnded: (() -> Void)?

    init() {
        silence = makeSilence()
        engine.attach(player)
        observeNotifications()
    }

    func start() {
        isActive = true
        activateSession()
        startSilence()
    }

    func stop() {
        isActive = false
        player.stop()
        engine.stop()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("Session deactivation failed: \(error.localizedDescription)")
        }
    }

    /// Safety net called periodically: restarts silence if the engine stopped without a notification.
    func ensureRunning() {
        guard isActive, !engine.isRunning || !player.isPlaying else { return }
        log.info("Silence loop not running, restarting")
        activateSession()
        startSilence()
    }

    private func activateSession() {
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            log.error("Session activation failed: \(error.localizedDescription)")
        }
    }

    private func startSilence() {
        guard let format, let silence else { return }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
            } catch {
                log.error("Engine start failed: \(error.localizedDescription)")
                return
            }
        }
        player.stop()
        player.scheduleBuffer(silence, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    private func makeSilence() -> AVAudioPCMBuffer? {
        guard let format,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(format.sampleRate))
        else { return nil }
        buffer.frameLength = buffer.frameCapacity
        if let channels = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                channels[channel].update(repeating: 0, count: Int(buffer.frameLength))
            }
        }
        return buffer
    }

    private func rebuildEngine() {
        engine.stop()
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        engine.attach(player)
        observeEngineConfiguration()
    }

    // MARK: - Notifications

    private var engineConfigObserver: NSObjectProtocol?

    private func observeNotifications() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                self?.handleInterruption(rawType: rawType)
            }
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMediaServicesReset()
            }
        }
        observeEngineConfiguration()
    }

    private func observeEngineConfiguration() {
        if let engineConfigObserver {
            NotificationCenter.default.removeObserver(engineConfigObserver)
        }
        engineConfigObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isActive else { return }
                log.info("Engine configuration changed, restarting silence")
                self.startSilence()
            }
        }
    }

    private func handleInterruption(rawType: UInt?) {
        guard let rawType, let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            log.info("Interruption began")
        case .ended:
            log.info("Interruption ended")
            guard isActive else { return }
            // Resume regardless of shouldResume: the workout timer must keep talking.
            activateSession()
            startSilence()
            onInterruptionEnded?()
        @unknown default:
            break
        }
    }

    private func handleMediaServicesReset() {
        log.error("Media services were reset")
        rebuildEngine()
        guard isActive else { return }
        activateSession()
        startSilence()
    }
}

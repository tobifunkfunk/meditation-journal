import Foundation
import UIKit
import Observation

/// Options captured when a timer starts.
struct TimerSettings {
    var preparationSeconds = 10
    var intervalMinutes = 0        // 0 = no interval bells
    var startBell = true
    var endBell = true
    var soundOn = true
    var hapticsOn = true
    var keepAwake = true
}

/// Drives a single meditation timer: an optional silent preparation lead-in,
/// then a counting session with start/interval/end bells, and finally logging
/// the completed minutes.
@MainActor
@Observable
final class TimerEngine {
    enum Phase { case idle, preparing, running, finished }

    private(set) var phase: Phase = .idle
    private(set) var totalSeconds = 0
    private(set) var elapsed = 0
    private(set) var prepRemaining = 0

    /// Called with (startDate, minutes) when a session should be recorded.
    var onLog: ((Date, Int) -> Void)?

    private var settings = TimerSettings()
    private var startDate = Date.now
    private var ticker: Timer?

    var remainingSeconds: Int { max(0, totalSeconds - elapsed) }
    var progress: Double { totalSeconds > 0 ? Double(elapsed) / Double(totalSeconds) : 0 }
    var isActive: Bool { phase == .preparing || phase == .running }

    func start(minutes: Int, settings: TimerSettings) {
        self.settings = settings
        totalSeconds = minutes * 60
        elapsed = 0
        prepRemaining = settings.preparationSeconds

        BellPlayer.shared.activate()

        if prepRemaining > 0 {
            phase = .preparing
        } else {
            begin()
        }

        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Stops early, logging the partial session if it ran at least a minute.
    func stop() {
        if phase == .running {
            let minutes = elapsed / 60
            if minutes >= 1 { onLog?(startDate, minutes) }
        }
        cleanup()
        BellPlayer.shared.deactivate()
        phase = .idle
    }

    /// Dismisses the finished screen back to setup.
    func reset() {
        cleanup()
        BellPlayer.shared.deactivate()
        phase = .idle
        elapsed = 0
    }

    private func begin() {
        phase = .running
        startDate = .now
        if settings.startBell { BellPlayer.shared.play(.start, sound: settings.soundOn, haptics: settings.hapticsOn) }
    }

    private func tick() {
        switch phase {
        case .preparing:
            prepRemaining -= 1
            if prepRemaining <= 0 { begin() }
        case .running:
            elapsed += 1
            let interval = settings.intervalMinutes * 60
            if interval > 0, elapsed % interval == 0, elapsed < totalSeconds {
                BellPlayer.shared.play(.interval, sound: settings.soundOn, haptics: settings.hapticsOn)
            }
            if elapsed >= totalSeconds { finish() }
        default:
            break
        }
    }

    private func finish() {
        if settings.endBell { BellPlayer.shared.play(.end, sound: settings.soundOn, haptics: settings.hapticsOn) }
        let minutes = max(1, Int((Double(totalSeconds) / 60).rounded()))
        onLog?(startDate, minutes)
        cleanup()
        phase = .finished
        // Let the end bell ring out before releasing the audio session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { BellPlayer.shared.deactivate() }
    }

    private func cleanup() {
        ticker?.invalidate()
        ticker = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

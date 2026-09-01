import Foundation
import AVFoundation
import UIKit

enum BellKind { case start, interval, end }

/// Plays meditation bells.
///
/// Key detail: it uses the `.playback` audio session category, which plays
/// **even when the phone's silent switch is on** — a meditating user almost
/// always has the ringer off, which is why `AudioServicesPlaySystemSound`
/// (the previous approach) was silent on device. Tones are synthesised, so no
/// audio files need to be bundled.
final class BellPlayer {
    static let shared = BellPlayer()

    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [BellKind: AVAudioPCMBuffer] = [:]

    private init() {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        buffers[.start] = makeBell(frequency: 528)
        buffers[.interval] = makeBell(frequency: 660)
        buffers[.end] = makeBell(frequency: 432, duration: 2.6)
    }

    /// Prepares audio output. Call when a session begins.
    func activate() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
        } catch {
            print("BellPlayer activate failed: \(error)")
        }
    }

    /// Releases audio output. Call when a session ends.
    func deactivate() {
        node.stop()
        if engine.isRunning { engine.pause() }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func play(_ kind: BellKind, sound: Bool, haptics: Bool) {
        if haptics {
            UINotificationFeedbackGenerator().notificationOccurred(kind == .end ? .success : .warning)
        }
        guard sound, let buffer = buffers[kind] else { return }
        if !engine.isRunning { activate() }
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    /// Synthesises a bell: a few inharmonic partials under an exponential decay.
    private func makeBell(frequency: Double, duration: Double = 1.9) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]

        let partials: [(ratio: Double, amp: Double)] = [
            (1.0, 1.0), (2.01, 0.5), (2.99, 0.28), (4.19, 0.14)
        ]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let envelope = exp(-3.2 * t)
            var value = 0.0
            for p in partials { value += p.amp * sin(2 * .pi * frequency * p.ratio * t) }
            samples[i] = Float(value * envelope * 0.18)
        }
        return buffer
    }
}

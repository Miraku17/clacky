import AVFoundation
import Foundation
import os

private let log = Logger(subsystem: "com.zianvalles.clacky", category: "audio")

/// A fixed pool of player nodes so rapid overlapping keystrokes all sound.
/// Buffers must be in `AudioBuffers.canonicalFormat`.
public final class AudioEngine {
    private struct Voice { let player: AVAudioPlayerNode; let varispeed: AVAudioUnitVarispeed }
    private let engine = AVAudioEngine()
    private var voices: [Voice] = []
    private var next = 0
    private let lock = NSLock()
    public private(set) var lastError: String?
    /// The clamped rate handed to the most recent voice (1 = natural pitch).
    public private(set) var lastAppliedRate: Float = 1
    /// The clamped pan handed to the most recent voice (−1 left … 1 right).
    public private(set) var lastAppliedPan: Float = 0

    public init(voices: Int = 16) {
        for _ in 0..<max(1, voices) {
            let player = AVAudioPlayerNode()
            let varispeed = AVAudioUnitVarispeed()
            engine.attach(player)
            engine.attach(varispeed)
            engine.connect(player, to: varispeed, format: AudioBuffers.canonicalFormat)
            engine.connect(varispeed, to: engine.mainMixerNode, format: AudioBuffers.canonicalFormat)
            self.voices.append(Voice(player: player, varispeed: varispeed))
        }
        engine.prepare()
    }

    /// An engine that renders into memory instead of the speakers, `offlineFrames`
    /// at a time. Used to check what the mix actually sounds like.
    public convenience init(voices: Int, offlineFrames: AVAudioFrameCount) throws {
        self.init(voices: voices)
        engine.stop()
        try engine.enableManualRenderingMode(.offline, format: AudioBuffers.canonicalFormat,
                                             maximumFrameCount: offlineFrames)
        engine.prepare()
    }

    /// Renders the next `frames` of the mix. Only valid for an offline engine.
    public func renderOffline(frames: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        lock.lock(); defer { lock.unlock() }
        let out = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: frames)!
        let status = try engine.renderOffline(frames, to: out)
        guard status == .success else { throw AudioBuffers.Error.conversionFailed("offline render status \(status.rawValue)") }
        return out
    }

    public var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = max(0, min(1, newValue)) }
    }

    /// Schedules the buffer on the next voice at `rate` (1 = natural pitch, clamped 0.5…2).
    /// Starts (or restarts, after an output-device change) the engine lazily.
    public func play(_ buffer: AVAudioPCMBuffer, rate: Float = 1, pan: Float = 0) {
        lock.lock(); defer { lock.unlock() }
        if !engine.isRunning {
            do { try engine.start(); lastError = nil; log.notice("audio engine started") }
            catch {
                lastError = "Audio engine: \(error.localizedDescription)"
                log.error("audio engine start failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        let voice = voices[next]
        next = (next + 1) % voices.count
        let clamped = max(0.5, min(2, rate))
        lastAppliedRate = clamped
        voice.varispeed.rate = clamped
        let clampedPan = max(-1, min(1, pan))
        lastAppliedPan = clampedPan
        voice.player.pan = clampedPan
        voice.player.stop()
        voice.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        voice.player.play()
    }
}

import AVFoundation
import Foundation
import os

private let log = Logger(subsystem: "com.zianvalles.clacky", category: "audio")

/// A fixed pool of player nodes so rapid overlapping keystrokes all sound.
/// Buffers must be in `AudioBuffers.canonicalFormat`.
public final class AudioEngine {
    private let engine = AVAudioEngine()
    private var nodes: [AVAudioPlayerNode] = []
    private var next = 0
    private let lock = NSLock()
    public private(set) var lastError: String?

    public init(voices: Int = 16) {
        for _ in 0..<max(1, voices) {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: AudioBuffers.canonicalFormat)
            nodes.append(node)
        }
        engine.prepare()
    }

    public var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = max(0, min(1, newValue)) }
    }

    /// Schedules the buffer on the next voice. Starts (or restarts, after an
    /// output-device change) the engine lazily.
    public func play(_ buffer: AVAudioPCMBuffer) {
        lock.lock(); defer { lock.unlock() }
        if !engine.isRunning {
            do { try engine.start(); lastError = nil; log.notice("audio engine started") }
            catch {
                lastError = "Audio engine: \(error.localizedDescription)"
                log.error("audio engine start failed: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        let node = nodes[next]
        next = (next + 1) % nodes.count
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        node.play()
    }
}

import Foundation
import AVFoundation
import Observation

private nonisolated final class RenderValue: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Float

    init(_ value: Float) {
        storage = value
    }

    var value: Float {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
        set {
            lock.lock()
            storage = newValue
            lock.unlock()
        }
    }
}

private nonisolated final class OscillatorPhase: @unchecked Sendable {
    var left: Float = 0.0
    var right: Float = 0.0
}

private nonisolated final class NoiseState: @unchecked Sendable {
    var seed: UInt32
    var lastOutput: Float

    init(seed: UInt32, lastOutput: Float = 0.0) {
        self.seed = seed
        self.lastOutput = lastOutput
    }
}

private enum PlaybackState {
    case stopped
    case starting
    case playing
    case stopping
}

/// The central audio engine for Drift.
///
/// This controller manages:
/// 1. **Binaural Beats**: Dual sine wave generation (Left vs Right channel).
/// 2. **Atmosphere**: Procedural noise generation (Brown/White noise).
/// 3. **Mixing**: Volume and panning control for all layers.
///
/// It uses `Observable` (Swift 6) to drive UI updates intuitively.
@Observable
@MainActor
class AudioController {
    static let shared = AudioController()

    // MARK: - Core Engine
    private let engine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode

    // MARK: - Nodes
    // 1. Binaural Tone
    private var sourceNode: AVAudioSourceNode! // The sine wave generator
    private let panningMixer = AVAudioMixerNode() // Handles LFO panning

    // 2. Atmosphere (Noise Layers)
    private var rainNode: AVAudioSourceNode! // Brown Noise
    private let rainMixer = AVAudioMixerNode()

    private var whiteNoiseNode: AVAudioSourceNode! // White Noise
    private let whiteNoiseMixer = AVAudioMixerNode()

    // MARK: - State
    var isPlaying: Bool = false

    /// The target frequency difference for entrainment (e.g., 6Hz).
    var frequency: Float = 6.0

    /// Global app volume (0.0 - 1.0).
    var masterVolume: Float = 1.0 {
        didSet { updateVolumes() }
    }

    /// Volume for the Rain (Brown Noise) layer.
    var rainVolume: Float = 0.0 {
        didSet { updateVolumes() }
    }

    /// Volume for the White Noise layer.
    var whiteNoiseVolume: Float = 0.0 {
        didSet { updateVolumes() }
    }

    // MARK: - Internal Audio State
    private var lfoPhase: Float = 0.0
    private let lfoRate: Float = 0.1 // Hz (Slow panning speed)
    private var lfoTask: Task<Void, Never>? // For LFO updates
    private var fadeTask: Task<Void, Never>? // For volume fades
    private var playbackState: PlaybackState = .stopped

    // Render-thread state is kept outside the observed, main-actor UI model.
    @ObservationIgnored private let frequencyValue = RenderValue(6.0)
    @ObservationIgnored private let carrierValue = RenderValue(200.0)
    @ObservationIgnored private let phase = OscillatorPhase()

    // MARK: - Initialization
    init() {
        mainMixer = engine.mainMixerNode
        setupEngine()
    }

    // MARK: - Engine Setup
    private func setupEngine() {
        // 1. Configure Audio Session (iOS)
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Failed to setup Audio Session: \(error)")
        }
        #endif

        // 2. Create the Binaural Source Node
        // This block runs thousands of times per second (at 44.1kHz).
        // It generates the raw sine wave samples.
        sourceNode = Self.makeToneNode(
            frequencyValue: frequencyValue,
            carrierValue: carrierValue,
            phase: phase
        )

        // 4. Connect Tone Nodes
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        engine.attach(sourceNode)
        engine.attach(panningMixer)
        engine.connect(sourceNode, to: panningMixer, format: format)
        engine.connect(panningMixer, to: mainMixer, format: format)

        // 5. Setup Atmosphere (Noise)
        setupAtmosphere(format: format)

        // 6. Start Subsystems
        startLFO() // Begin panning timer
        engine.prepare()
        updateVolumes()
    }

    private func setupAtmosphere(format: AVAudioFormat) {
        // --- Rain (Brown Noise) ---
        // Uses a Linear Congruential Generator (LCG) for performant pseudo-random noise.
        // Brown noise is "smoothed" white noise (low pass filtered).
        rainNode = Self.makeRainNode()

        // --- White Noise ---
        // Pure random signal across all frequencies.
        whiteNoiseNode = Self.makeWhiteNoiseNode()

        // Connect Atmosphere Nodes
        engine.attach(rainNode)
        engine.attach(rainMixer)
        engine.connect(rainNode, to: rainMixer, format: format)
        engine.connect(rainMixer, to: mainMixer, format: format)

        engine.attach(whiteNoiseNode)
        engine.attach(whiteNoiseMixer)
        engine.connect(whiteNoiseNode, to: whiteNoiseMixer, format: format)
        engine.connect(whiteNoiseMixer, to: mainMixer, format: format)
    }

    private nonisolated static func makeToneNode(
        frequencyValue: RenderValue,
        carrierValue: RenderValue,
        phase: OscillatorPhase
    ) -> AVAudioSourceNode {
        AVAudioSourceNode { [frequencyValue, carrierValue, phase] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)

            let entrainmentHz = frequencyValue.value
            let carrierHz = carrierValue.value
            let sampleRate = 44100.0
            let twoPi = 2.0 * Float.pi

            let incL = (carrierHz * twoPi) / Float(sampleRate)
            let incR = ((carrierHz + entrainmentHz) * twoPi) / Float(sampleRate)

            var phaseL = phase.left
            var phaseR = phase.right

            let bufferL = UnsafeMutableBufferPointer<Float>(abl[0])
            let bufferR = (abl.count > 1) ? UnsafeMutableBufferPointer<Float>(abl[1]) : nil

            for frame in 0..<Int(frameCount) {
                let valL = sin(phaseL)
                let valR = sin(phaseR)

                phaseL += incL
                if phaseL > twoPi { phaseL -= twoPi }

                phaseR += incR
                if phaseR > twoPi { phaseR -= twoPi }

                if frame < bufferL.count {
                    bufferL[frame] = valL * 0.4
                }
                if let bufferR = bufferR, frame < bufferR.count {
                    bufferR[frame] = valR * 0.4
                }
            }

            phase.left = phaseL
            phase.right = phaseR

            return noErr
        }
    }

    private nonisolated static func makeRainNode() -> AVAudioSourceNode {
        let rainState = NoiseState(seed: 123456789)

        return AVAudioSourceNode { [rainState] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                rainState.seed = rainState.seed &* 1664525 &+ 1013904223
                let white = (Float(rainState.seed) / 4294967295.0) * 2.0 - 1.0

                var brown = (rainState.lastOutput + (0.02 * white)) / 1.02
                rainState.lastOutput = brown
                brown *= 3.5

                for buffer in abl {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count { buf[frame] = brown * 0.1 }
                }
            }
            return noErr
        }
    }

    private nonisolated static func makeWhiteNoiseNode() -> AVAudioSourceNode {
        let whiteNoiseState = NoiseState(seed: 987654321)

        return AVAudioSourceNode { [whiteNoiseState] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                whiteNoiseState.seed = whiteNoiseState.seed &* 1664525 &+ 1013904223
                let white = (Float(whiteNoiseState.seed) / 4294967295.0) * 2.0 - 1.0

                for buffer in abl {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count { buf[frame] = white * 0.03 }
                }
            }
            return noErr
        }
    }

    // MARK: - Control Methods

    /// Updates the binaural beat frequency (e.g., 6Hz for Theta).
    func setFrequency(_ hz: Float) {
        frequencyValue.value = hz
        self.frequency = hz
    }

    private func updateVolumes() {
        mainMixer.outputVolume = masterVolume
        rainMixer.outputVolume = rainVolume
        whiteNoiseMixer.outputVolume = whiteNoiseVolume
    }

    func start() {
        fadeTask?.cancel()

        if engine.isRunning {
            playbackState = .playing
            isPlaying = true
            fade(node: mainMixer, target: masterVolume, duration: 0.4)
            return
        }

        // 1. Prepare for fade-in
        // We fade the Main Mixer so ALL sounds (Rain, Noise, Tone) fade in together.

        // Ensure subsystems are ready (but silent due to mainMixer)
        panningMixer.outputVolume = 1.0
        updateVolumes() // Sets Rain/Noise to their slider levels

        // Start silent
        mainMixer.outputVolume = 0

        do {
            try engine.start()
            playbackState = .starting
            isPlaying = true

            // 3. Global Fade In
            // Fade MainMixer from 0 -> MasterVolume
            fade(node: mainMixer, target: masterVolume, duration: 2.0) { [weak self] in
                self?.playbackState = .playing
            }
        } catch {
            playbackState = .stopped
            isPlaying = false
            print("Error starting engine: \(error)")
        }
    }

    func stop() {
        guard playbackState != .stopped else { return }

        fadeTask?.cancel()
        playbackState = .stopping
        isPlaying = false

        // 3. Global Fade Out
        fade(node: mainMixer, target: 0.0, duration: 1.0) { [weak self] in
            guard let self, self.playbackState == .stopping else { return }
            self.engine.stop()
            self.engine.reset()
            self.playbackState = .stopped
        }
    }

    // MARK: - Helpers

    /// Animates the volume of a node linearly.
    private func fade(node: AVAudioMixerNode, target: Float, duration: TimeInterval, completion: (@MainActor @Sendable () -> Void)? = nil) {
        fadeTask?.cancel()

        let startVolume = node.outputVolume
        let steps = 30
        let interval = duration / Double(steps)
        let stepAmount = (target - startVolume) / Float(steps)

        fadeTask = Task { @MainActor [weak self] in
            guard self != nil else { return }

            for _ in 0..<steps {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { return }
                node.outputVolume += stepAmount
            }

            node.outputVolume = target
            completion?()
        }
    }

    /// Starts the Low Frequency Oscillator (LFO) for Panning.
    /// This slowly moves the sound between Left and Right ears.
    private func startLFO() {
        lfoTask?.cancel()
        lfoTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.0 / 60.0))

                guard let self, self.isPlaying else { continue }

                self.lfoPhase += self.lfoRate / 60.0
                if self.lfoPhase > .pi * 2 { self.lfoPhase -= .pi * 2 }

                // Pan calculates sine wave from -0.8 to 0.8
                let panPosition = sin(self.lfoPhase) * 0.8
                self.panningMixer.pan = panPosition
            }
        }
    }
}

import Foundation
import AVFoundation
import Observation

/// The central audio engine for Drift.
///
/// This controller manages:
/// 1. **Binaural Beats**: Dual sine wave generation (Left vs Right channel).
/// 2. **Atmosphere**: Procedural noise generation (Brown/White noise).
/// 3. **Mixing**: Volume and panning control for all layers.
///
/// It uses `Observable` (Swift 6) to drive UI updates intuitively.
@Observable
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
    private var timer: Timer? // For LFO updates
    private var fadeTimer: Timer? // For volume fades
    
    // Unsafe Pointers for Real-Time Audio Threads
    // We use pointers because the audio render block is a C-function callback that
    // requires lock-free access to shared data.
    private var frequencyPointer: UnsafeMutablePointer<Float>?
    private var carrierPointer: UnsafeMutablePointer<Float>?
    private var phaseLPointer: UnsafeMutablePointer<Float>?
    private var phaseRPointer: UnsafeMutablePointer<Float>?
    
    // MARK: - Initialization
    init() {
        mainMixer = engine.mainMixerNode
        setupEngine()
    }
    
    deinit {
        // Always clean up manually allocated memory
        frequencyPointer?.deallocate()
        carrierPointer?.deallocate()
        phaseLPointer?.deallocate()
        phaseRPointer?.deallocate()
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
        
        // 2. Allocate Memory for Audio Thread communication
        // These pointers allow us to change frequency/phase from the main thread
        // while the background audio thread reads them instantly.
        let frequencyPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        frequencyPointer.initialize(to: 6.0)
        
        let carrierPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        carrierPointer.initialize(to: 200.0) // Carrier Tone (Base pitch)
        
        let phaseLPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        phaseLPointer.initialize(to: 0.0)
        
        let phaseRPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        phaseRPointer.initialize(to: 0.0)
        
        // Store references
        self.frequencyPointer = frequencyPointer
        self.carrierPointer = carrierPointer
        self.phaseLPointer = phaseLPointer
        self.phaseRPointer = phaseRPointer
        
        // 3. Create the Binaural Source Node
        // This block runs thousands of times per second (at 44.1kHz).
        // It generates the raw sine wave samples.
        sourceNode = AVAudioSourceNode { [frequencyPointer, carrierPointer, phaseLPointer, phaseRPointer] _, _, frameCount, audioBufferList -> OSStatus in
            
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            // Read current values safely
            let entrainmentHz = frequencyPointer.pointee
            let carrierHz = carrierPointer.pointee
            let sampleRate = 44100.0
            let twoPi = 2.0 * Float.pi
            
            // Calculate increment per sample for Left vs Right
            // Left = Carrier (200Hz)
            // Right = Carrier + Entrainment (206Hz) -> Beats at 6Hz
            let incL = (carrierHz * twoPi) / Float(sampleRate)
            let incR = ((carrierHz + entrainmentHz) * twoPi) / Float(sampleRate)
            
            var phaseL = phaseLPointer.pointee
            var phaseR = phaseRPointer.pointee
            
            let bufferL = UnsafeMutableBufferPointer<Float>(abl[0])
            let bufferR = (abl.count > 1) ? UnsafeMutableBufferPointer<Float>(abl[1]) : nil
            
            for frame in 0..<Int(frameCount) {
                // Generate Sine Sample
                let valL = sin(phaseL)
                let valR = sin(phaseR)
                
                // Advance Phase
                phaseL += incL
                if phaseL > twoPi { phaseL -= twoPi }
                
                phaseR += incR
                if phaseR > twoPi { phaseR -= twoPi }
                
                // Write to buffer (scaled volume 0.4)
                if frame < bufferL.count {
                    bufferL[frame] = valL * 0.4
                }
                if let bufferR = bufferR, frame < bufferR.count {
                    bufferR[frame] = valR * 0.4
                }
            }
            
            // Save state back for next block
            phaseLPointer.pointee = phaseL
            phaseRPointer.pointee = phaseR
            
            return noErr
        }
        
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
        var lcgStateRain: UInt32 = 123456789
        var lastOut: Float = 0.0
        
        rainNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                // Generate White Noise (-1.0 to 1.0)
                lcgStateRain = lcgStateRain &* 1664525 &+ 1013904223
                let white = (Float(lcgStateRain) / 4294967295.0) * 2.0 - 1.0
                
                // Apply Low Pass Filter for Brown Noise
                var brown = (lastOut + (0.02 * white)) / 1.02
                lastOut = brown
                brown *= 3.5 // Boost volume to Normalize
                
                for buffer in abl {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count { buf[frame] = brown * 0.1 }
                }
            }
            return noErr
        }
        
        // --- White Noise ---
        // Pure random signal across all frequencies.
        var lcgStateWhite: UInt32 = 987654321
        
        whiteNoiseNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                lcgStateWhite = lcgStateWhite &* 1664525 &+ 1013904223
                let white = (Float(lcgStateWhite) / 4294967295.0) * 2.0 - 1.0
                
                for buffer in abl {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count { buf[frame] = white * 0.03 } 
                }
            }
            return noErr
        }
        
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
    
    // MARK: - Control Methods
    
    /// Updates the binaural beat frequency (e.g., 6Hz for Theta).
    func setFrequency(_ hz: Float) {
        frequencyPointer?.pointee = hz
        self.frequency = hz
    }
    
    private func updateVolumes() {
        mainMixer.outputVolume = masterVolume
        rainMixer.outputVolume = rainVolume
        whiteNoiseMixer.outputVolume = whiteNoiseVolume
    }
    
    func start() {
        if engine.isRunning { return }
        
        // 1. Prepare for fade-in
        // We fade the Main Mixer so ALL sounds (Rain, Noise, Tone) fade in together.
        
        // Ensure subsystems are ready (but silent due to mainMixer)
        panningMixer.outputVolume = 1.0 
        updateVolumes() // Sets Rain/Noise to their slider levels
        
        // Start silent
        mainMixer.outputVolume = 0 
        
        do {
            try engine.start()
            isPlaying = true
            
            // 2. Global Fade In
            // Fade MainMixer from 0 -> MasterVolume
            fade(node: mainMixer, target: masterVolume, duration: 2.0)
        } catch {
            print("Error starting engine: \(error)")
        }
    }
    
    func stop() {
        isPlaying = false
        // 3. Global Fade Out
        fade(node: mainMixer, target: 0.0, duration: 1.0) { [weak self] in
            self?.engine.stop()
            self?.engine.reset()
        }
    }
    
    // MARK: - Helpers
    
    /// Animates the volume of a node linearly.
    private func fade(node: AVAudioMixerNode, target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        
        let startVolume = node.outputVolume
        let steps = 30
        let interval = duration / Double(steps)
        let stepAmount = (target - startVolume) / Float(steps)
        
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let _ = self else { timer.invalidate(); return }
            
            step += 1
            node.outputVolume += stepAmount
            
            if step >= steps {
                node.outputVolume = target
                timer.invalidate()
                completion?()
            }
        }
    }
    
    /// Starts the Low Frequency Oscillator (LFO) for Panning.
    /// This slowly moves the sound between Left and Right ears.
    private func startLFO() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            
            self.lfoPhase += self.lfoRate / 60.0
            if self.lfoPhase > .pi * 2 { self.lfoPhase -= .pi * 2 }
            
            // Pan calculates sine wave from -0.8 to 0.8
            let panPosition = sin(self.lfoPhase) * 0.8
            self.panningMixer.pan = panPosition
        }
    }
}

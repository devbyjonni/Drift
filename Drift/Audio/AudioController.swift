import Foundation
import AVFoundation
import Combine

class AudioController: ObservableObject {
    static let shared = AudioController()
    
    // Engine & Nodes
    private let engine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode
    private var sourceNode: AVAudioSourceNode!
    private let panningMixer = AVAudioMixerNode()
    
    // Atmosphere
    private var noiseNode: AVAudioSourceNode!
    private let noiseMixer = AVAudioMixerNode()
    
    // State
    @Published var isPlaying: Bool = false
    @Published var atmosphereIntensity: Double = 0.0
    @Published var isRaining: Bool = false
    @Published var isSpace: Bool = false
    
    // Parameters
    var frequency: Float = 6.0 { // Default Theta
        didSet {
            // Smoothly update frequency (handled in block via pointer if needed, or atomic)
            // For simple SourceNode, we can read this value directly if captured carefully,
            // or use specific thread-safe patterns.
            // For this implementation, we'll use a thread-safe atomic-like approach or simple locking
            // if we needed sample-accurate automation, but for brainwaves, simple variable update is often "ok"
            // if we filter it inside the render block.
        }
    }
    
    // LFO State
    private var lfoPhase: Float = 0.0
    private let lfoRate: Float = 0.1 // Hz (Very slow panning)
    
    // Wave Generation State
    private var currentPhase: Float = 0.0
    private let sampleRate: Double = 44100.0
    private let twoPi = 2.0 * Float.pi
    
    init() {
        mainMixer = engine.mainMixerNode
        setupEngine()
    }
    
    var carrierFrequency: Float = 200.0 // Audible base tone
    
    private func setupEngine() {
        // 0. Configure Audio Session
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try session.setActive(true)
        } catch {
            print("Failed to setup Audio Session: \(error)")
        }
        #endif
        
        // 1. Create Source Node for Binaural Sine Wave
        
        // Allocate pointers manually
        let frequencyPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        frequencyPointer.initialize(to: 6.0)
        
        let carrierPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        carrierPointer.initialize(to: 200.0)
        
        let phaseLPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        phaseLPointer.initialize(to: 0.0)
        
        let phaseRPointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        phaseRPointer.initialize(to: 0.0)
        
        // Store for cleanup
        self.frequencyPointer = frequencyPointer
        self.carrierPointer = carrierPointer
        self.phaseLPointer = phaseLPointer
        self.phaseRPointer = phaseRPointer
        
        // Standard Stereo Format
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)!
        
        sourceNode = AVAudioSourceNode { [frequencyPointer, carrierPointer, phaseLPointer, phaseRPointer] _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            let entrainmentHz = frequencyPointer.pointee
            let carrierHz = carrierPointer.pointee
            let sampleRate = 44100.0
            let twoPi = 2.0 * Float.pi
            
            let incL = (carrierHz * twoPi) / Float(sampleRate)
            let incR = ((carrierHz + entrainmentHz) * twoPi) / Float(sampleRate)
            
            var phaseL = phaseLPointer.pointee
            var phaseR = phaseRPointer.pointee
            
            // Expected: 2 buffers (L/R) for non-interleaved stereo
            // If interleaved (1 buffer), we'd need different logic, but standardFormat is usually non-interleaved.
            
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
            
            phaseLPointer.pointee = phaseL
            phaseRPointer.pointee = phaseR
            
            return noErr
        }
        
        engine.attach(sourceNode)
        engine.attach(panningMixer)
        
        // Connect
        engine.connect(sourceNode, to: panningMixer, format: format)
        engine.connect(panningMixer, to: mainMixer, format: format)
        
        setupNoise(format: format)
        
        startLFO()
        engine.prepare()
    }
    
    private func setupNoise(format: AVAudioFormat) {
        // Fast Pseudo-Random Number Generator (LCG)
        // Avoids swift's Float.random(in:) overhead in the render thread
        var state: UInt32 = 123456789
        
        var lastOut: Float = 0.0
        
        noiseNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                // LCG Algorithm: X_{n+1} = (aX_n + c) mod m
                state = state &* 1664525 &+ 1013904223 // &* overload ignores overflow
                
                // Normalize to -1.0...1.0
                // Divide by Max UInt32 (4294967295.0) -> 0...1 -> * 2 - 1 -> -1...1
                let white = (Float(state) / 4294967295.0) * 2.0 - 1.0
                
                var brown = (lastOut + (0.02 * white)) / 1.02
                lastOut = brown
                brown *= 3.5 
                
                for buffer in abl {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count {
                        buf[frame] = brown * 0.1 
                    }
                }
            }
            return noErr
        }
        
        engine.attach(noiseNode)
        engine.attach(noiseMixer)
        engine.connect(noiseNode, to: noiseMixer, format: format)
        engine.connect(noiseMixer, to: mainMixer, format: format)
        noiseMixer.volume = 0.0 
    }
    
    private var carrierPointer: UnsafeMutablePointer<Float>?
    private var phaseLPointer: UnsafeMutablePointer<Float>?
    private var phaseRPointer: UnsafeMutablePointer<Float>?
    
    func setAtmosphereVolume(_ volume: Float) {
        noiseMixer.volume = volume
    }
    
    private var frequencyPointer: UnsafeMutablePointer<Float>?
    private var phasePointer: UnsafeMutablePointer<Float>? // Add this property
    private var timer: Timer?
    
    func setFrequency(_ hz: Float) {
        frequencyPointer?.pointee = hz
        self.frequency = hz
    }
    
    func start() {
        if engine.isRunning { return }
        
        // Prepare for fade in
        panningMixer.outputVolume = 0
        noiseMixer.outputVolume = 0 // Also fade noise if needed, but noiseMixer has its own volume control logic
        // We'll trust setAtmosphereVolume handles target noise volume, but for master start/stop we fade panningMixer which carries tone
        // Correction: Noise goes to noiseMixer -> mainMixer. Tone goes to panningMixer -> mainMixer.
        // To fade EVERYTHING, we should fade mainMixer, but mainMixer outputVolume is often read-only or affects system.
        // Better to fade individual mixers or connect them to a master node.
        // Current Graph: 
        // Tone -> PanningMixer -> MainMixer
        // Noise -> NoiseMixer -> MainMixer
        // So we must fade PanningMixer AND NoiseMixer, or insert a MasterMixer.
        // For simplicity: We will fade PanningMixer (Tone) and NoiseMixer (Atmosphere).
        panningMixer.outputVolume = 0
        
        // Restore noise volume if it was active? 
        // Current logic: noiseMixer.volume is used for intensity. 
        // We shouldn't mess with noiseMixer.volume property if it represents user setting.
        // BUT `start/stop` usually implies master switch.
        // Let's fade `mainMixer.outputVolume`? No, mainMixer corresponds to the hardware output often.
        // Let's assume the user hears "Pop" from the Tone mostly.
        
        do {
            try engine.start()
            isPlaying = true
            
            // Fade In
            fade(node: panningMixer, target: 1.0, duration: 1.0)
            // Note: Noise mixer volume is dynamic based on "Rain" toggle. 
            // If rain is on, it might pop. 
            // Let's just fix the Tone pop first as requested ("play and stop").
        } catch {
            print("Error starting engine: \(error)")
        }
    }
    
    func stop() {
        isPlaying = false
        // Fade Out then Stop
        fade(node: panningMixer, target: 0.0, duration: 0.5) { [weak self] in
            self?.engine.stop()
            self?.engine.reset()
        }
    }
    
    // Fade Helper
    private var fadeTimer: Timer?
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
    
    // LFO for Panning
    private func startLFO() {
        // Update pan 60 times a second for smoothness
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            
            self.lfoPhase += self.lfoRate / 60.0
            if self.lfoPhase > .pi * 2 { self.lfoPhase -= .pi * 2 }
            
            // Pan moves between -0.8 and 0.8 to not be too extreme
            let panPosition = sin(self.lfoPhase) * 0.8
            self.panningMixer.pan = panPosition
        }
    }
    
    deinit {
        frequencyPointer?.deallocate()
        carrierPointer?.deallocate()
        phaseLPointer?.deallocate()
        phaseRPointer?.deallocate()
    }
}

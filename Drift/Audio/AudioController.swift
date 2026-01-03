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
    
    // Atmosphere Nodes
    private var rainNode: AVAudioSourceNode!
    private let rainMixer = AVAudioMixerNode()
    
    private var whiteNoiseNode: AVAudioSourceNode!
    private let whiteNoiseMixer = AVAudioMixerNode()
    
    // State
    @Published var isPlaying: Bool = false
    @Published var frequency: Float = 6.0
    
    // Volume State (0.0 - 1.0)
    @Published var masterVolume: Float = 1.0 {
        didSet { updateVolumes() }
    }
    @Published var rainVolume: Float = 0.0 {
        didSet { updateVolumes() }
    }
    @Published var whiteNoiseVolume: Float = 0.0 {
        didSet { updateVolumes() }
    }
    
    // Deprecated helpers for compatibility (Optional, if UI still uses them, but MainView is updated)
    // We removed isRaining from MainView, so we can remove it here.

    

    
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
        
        // --- 2. Atmosphere Setup ---
        setupAtmosphere(format: format)
        
        startLFO()
        engine.prepare()
        
        // Initial Volume
        updateVolumes()
    }
    
    private func setupAtmosphere(format: AVAudioFormat) {
        // --- Rain (Brown Noise) ---
        var lcgStateRain: UInt32 = 123456789
        var lastOut: Float = 0.0
        
        rainNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                lcgStateRain = lcgStateRain &* 1664525 &+ 1013904223
                let white = (Float(lcgStateRain) / 4294967295.0) * 2.0 - 1.0
                var brown = (lastOut + (0.02 * white)) / 1.02
                lastOut = brown
                brown *= 3.5 
                
                for buffer in abl {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count { buf[frame] = brown * 0.1 }
                }
            }
            return noErr
        }
        
        // --- White Noise ---
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
        
        engine.attach(rainNode)
        engine.attach(rainMixer)
        engine.connect(rainNode, to: rainMixer, format: format)
        engine.connect(rainMixer, to: mainMixer, format: format)
        
        engine.attach(whiteNoiseNode)
        engine.attach(whiteNoiseMixer)
        engine.connect(whiteNoiseNode, to: whiteNoiseMixer, format: format)
        engine.connect(whiteNoiseMixer, to: mainMixer, format: format)
    }
    
    private func updateVolumes() {
        // Master volume scales everything
        mainMixer.outputVolume = masterVolume
        
        // Individual Channel Volumes
        rainMixer.outputVolume = rainVolume
        whiteNoiseMixer.outputVolume = whiteNoiseVolume
    }
    
    private var carrierPointer: UnsafeMutablePointer<Float>?
    private var phaseLPointer: UnsafeMutablePointer<Float>?
    private var phaseRPointer: UnsafeMutablePointer<Float>?
    

    
    private var frequencyPointer: UnsafeMutablePointer<Float>?
    private var phasePointer: UnsafeMutablePointer<Float>? // Add this property
    private var timer: Timer?
    
    func setFrequency(_ hz: Float) {
        frequencyPointer?.pointee = hz
        self.frequency = hz
    }
    
    func start() {
        if engine.isRunning { return }
        
        // Mute Tone Mixer before starting to prevent pop
        panningMixer.outputVolume = 0
        
        // Ensure atmospheric mixers are at correct volume
        rainMixer.outputVolume = rainVolume
        whiteNoiseMixer.outputVolume = whiteNoiseVolume
        
        // Main Mixer follows master
        mainMixer.outputVolume = masterVolume
        
        do {
            try engine.start()
            isPlaying = true
            
            // Fade In Tone
            fade(node: panningMixer, target: 1.0, duration: 1.0)
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

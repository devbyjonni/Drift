import SwiftUI

struct MainView: View {
    // MARK: - State
    @State private var selectedTab: BrainwaveState = .theta
    @State private var audioController = AudioController.shared
    @State private var showMixer: Bool = false
    
    var body: some View {
        ZStack {
            // 1. Background Layer
            BackgroundView(mode: selectedTab)
                .animation(.easeInOut(duration: 1.0), value: selectedTab)
            
            SpaceView(intensity: 0.8)
            
            // 2. Main Content
            VStack {
                headerView
                
                Spacer()
                
                frequencyTabView
                
                pageIndicator
                
                waveVisualization
                
                Spacer()
                
                playButton
            }
        }
        .onChange(of: selectedTab) { _, newState in
             handleTabChange(to: newState)
        }
        .onChange(of: audioController.isPlaying) { _, isPlaying in
            print(isPlaying)
            // Prevent screen lock while playing
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = isPlaying
            #endif
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Spacer()
            
            Text("DRIFT")
                .font(.caption)
                .tracking(2)
                .foregroundColor(Color(hex: Theme.Colors.textMuted))
            
            Spacer()
            
            Button(action: { showMixer = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundColor(Color(hex: Theme.Colors.textMuted))
            }
            .sheet(isPresented: $showMixer) {
                MixerView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .padding()
        .padding(.top)
    }
    
    private var frequencyTabView: some View {
        TabView(selection: $selectedTab) {
            ForEach(BrainwaveState.allCases) { state in
                VStack(spacing: 20) {
                    Text(state.rawValue)
                        .font(.system(size: 48, weight: .light, design: .rounded))
                        .foregroundColor(Color(hex: Theme.Colors.textLight))
                    
                    Text(state.displayLabel)
                        .font(.title3)
                        .foregroundColor(state == .alpha || state == .beta ? Color(hex: Theme.Colors.starlight) : Color(hex: Theme.Colors.primary))
                    
                    Text(state.description.uppercased())
                        .font(.caption)
                        .tracking(2)
                        .foregroundColor(Color(hex: Theme.Colors.textMuted))
                }
                .tag(state)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 200)
        // Disable interaction when playing to prevent accidental frequency jumps
        .allowsHitTesting(!audioController.isPlaying)
        .opacity(audioController.isPlaying ? 0.6 : 1.0)
        .animation(.easeInOut, value: audioController.isPlaying)
    }
    
    private var waveVisualization: some View {
        // Map Frequency to visual range (approx 2-15 cycles)
        let visualFreq = audioController.isPlaying ? Double(audioController.frequency) * 0.5 : 1.0
        
        return WaveView(
            frequency: visualFreq,
            amplitude: audioController.isPlaying ? 30 : 0
        )
        .frame(height: 120)
        .opacity(0.8)
        .animation(.easeInOut(duration: 1.5), value: visualFreq)
        .animation(.easeInOut(duration: 1.5), value: audioController.isPlaying)
    }
    
    private var playButton: some View {
        HStack(spacing: 40) {
            Button(action: {
                if audioController.isPlaying {
                    audioController.stop()
                } else {
                    audioController.start()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color(hex: Theme.Colors.textLight))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: audioController.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color(hex: Theme.Colors.backgroundDark))
                }
            }
        }
        .padding(.bottom, 60)
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(BrainwaveState.allCases) { state in
                Circle()
                    // Use textLight for both, just vary opacity for a cleaner look
                    .fill(Color(hex: Theme.Colors.textLight).opacity(state == selectedTab ? 0.8 : 0.2))
                    .frame(width: 8, height: 8)
                    .scaleEffect(state == selectedTab ? 1.0 : 0.8) // Subtle scale diff
                    .animation(.spring(), value: selectedTab)
            }
        }
        .opacity(audioController.isPlaying ? 0.0 : 1.0) // Hide completely when playing for cleaner look
        .animation(.easeInOut, value: audioController.isPlaying)
        .padding(.bottom, 10)
    }
    
    // MARK: - Logic
    
    private func handleTabChange(to newState: BrainwaveState) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        audioController.setFrequency(newState.centerFrequency)
    }
}

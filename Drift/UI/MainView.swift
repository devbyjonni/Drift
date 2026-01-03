import SwiftUI

struct MainView: View {
    @State private var selectedTab: BrainwaveState = .theta
    @StateObject private var audioController = AudioController.shared
    @State private var showMixer: Bool = false
    
    // UI State for animations
    
    
    var body: some View {
        ZStack {
            BackgroundView(mode: selectedTab)
                .animation(.easeInOut(duration: 1.0), value: selectedTab)
            
            // Atmospheric Visuals
            SpaceView(intensity: 0.8)
            

            
            // Main Content
            VStack {
                // Header
                HStack {
                    // Left: Empty/Spacer (removed chevron)
                    Spacer()
                    
                    // Center: Title + Hz
                    VStack(spacing: 2) {
                        Text("DRIFT")
                            .font(.caption)
                            .tracking(2)
                    }
                    .foregroundColor(Color(hex: Theme.Colors.textMuted))
                    
                    Spacer()
                    
                    // Right: Mixer Button
                    Button(action: {
                        showMixer = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(Color(hex: Theme.Colors.textMuted))
                    }
                    .sheet(isPresented: $showMixer) {
                        MixerView()
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
                }
                .padding()
                .padding(.top)
                
                Spacer()
                
                // Frequency Pages
                TabView(selection: $selectedTab) {
                    ForEach(BrainwaveState.allCases) { state in
                        VStack(spacing: 20) {
                            Text(state.rawValue)
                                .font(.system(size: 48, weight: .light, design: .rounded))
                                .foregroundColor(Color(hex: Theme.Colors.textLight))
                            
                            Text(state.displayLabel) // Shows "6.0 Hz" explicitly
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
                // DISABLE SWIPE WHEN PLAYING
                .allowsHitTesting(!audioController.isPlaying)
                // Visual opacity cue to show it's locked
                .opacity(audioController.isPlaying ? 0.6 : 1.0)
                .animation(.easeInOut, value: audioController.isPlaying)
                
                // Wave Visualization
                // Visual Frequency: Map 0.5-30Hz to fit screen (e.g., 2-10 cycles)
                // We'll scale it slightly so it doesn't look too chaotic at 30Hz
                let visualFreq = audioController.isPlaying ? Double(audioController.frequency) * 0.5 : 1.0
                
                WaveView(
                    frequency: visualFreq,
                    amplitude: audioController.isPlaying ? 30 : 5,
                    speed: audioController.isPlaying ? 2.0 : 0.5, // Scroll speed
                    color: Color(hex: Theme.Colors.primary)
                )
                .frame(height: 120)
                .opacity(0.8)
                // Use inbuilt implicit animation for frequency/amplitude changes
                .animation(.easeInOut(duration: 1.5), value: visualFreq)
                .animation(.easeInOut(duration: 1.5), value: audioController.isPlaying)
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    // Removed Rewind Button
                    
                    // Centered Play Button
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
                    
                    // Removed old Filter Button location (now empty/spacer if needed, or just center play)
                }
                .padding(.bottom, 60) // Extra padding since tab bar is gone
                
                // Removed Tab Bar
            }
        }
                .onChange(of: selectedTab) { newState in
             // Trigger Haptics
             let generator = UIImpactFeedbackGenerator(style: .light)
             generator.impactOccurred()
             
             // Update Audio - 100% Correct Source of Truth
             audioController.setFrequency(newState.centerFrequency)
        }
        .onAppear {
             // Ensure initial state is synced 100% on load
             audioController.setFrequency(selectedTab.centerFrequency)
        }
    }
}

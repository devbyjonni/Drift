import SwiftUI

struct MixerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var audioController = AudioController.shared
    
    var body: some View {
        ZStack {
            Color(hex: Theme.Colors.backgroundDark).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    ZStack {
                        // Title to center
                        Text("Mixer")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .tracking(2)
                            .foregroundColor(Color(hex: Theme.Colors.textLight).opacity(0.9))
                        
                        // Chevron to left (actually just dismiss zone)
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundColor(Color(hex: Theme.Colors.textLight).opacity(0.8))
                            }
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    audioController.rainVolume = 0
                                    audioController.whiteNoiseVolume = 0
                                    audioController.masterVolume = 1.0
                                }
                            }) {
                                Text("RESET")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .tracking(1)
                                    .foregroundColor(Color(hex: Theme.Colors.textMuted))
                            }
                        }
                    }
                }
                .padding()
                .padding(.top, 10)
                .background(Color(hex: Theme.Colors.surfaceDark).opacity(0.5))
                
                ScrollView {
                    VStack(spacing: 1) {
                        
                        // Section 1: Nature Elements
                        SectionHeader(icon: "cloud.rain", title: "Nature Elements")
                        
                        MixerSlider(
                            title: "Rain",
                            subtitle: "Heavy Downpour",
                            icon: "cloud.rain.fill",
                            value: $audioController.rainVolume,
                            color: Color(hex: Theme.Colors.textLight)
                        )
                        
                        Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 24).padding(.vertical, 8)
                        
                        // Section 2: Noise Colors
                        SectionHeader(icon: "waveform.path", title: "Noise Colors")
                        
                        MixerSlider(
                            title: "White Noise",
                            subtitle: "Static Block",
                            icon: "aqi.medium",
                            value: $audioController.whiteNoiseVolume,
                            color: Color(hex: Theme.Colors.textLight)
                        )
                        
                        Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 24).padding(.vertical, 8)

                        // Section 3: Master
                        SectionHeader(icon: "speaker.wave.3", title: "Master")
                        
                        MixerSlider(
                            title: "Master Volume",
                            subtitle: "Global Level",
                            icon: "speaker.wave.3.fill",
                            value: $audioController.masterVolume,
                            color: Color(hex: Theme.Colors.primary),
                            defaultValue: 1.0
                        )
                    }
                    .padding(.top, 20)
                }
                
                // Bottom Action
                Button(action: { dismiss() }) {
                    HStack {
                        Text("APPLY TO SESSION")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .tracking(2)
                        Image(systemName: "checkmark")
                    }
                    .foregroundColor(Color(hex: Theme.Colors.textLight))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: Theme.Colors.surfaceDark))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .cornerRadius(28)
                }
                .padding(24)
            }
        }
        .colorScheme(.dark)
    }
}

struct SectionHeader: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
            Text(title.uppercased())
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .tracking(1.5)
        }
        .foregroundColor(Color(hex: Theme.Colors.textLight).opacity(0.8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

struct MixerSlider: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var value: Float
    var color: Color
    var defaultValue: Float = 0.0
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(value > 0 ? Color(hex: Theme.Colors.textLight) : Color(hex: Theme.Colors.textMuted))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(value > 0 ? Color(hex: Theme.Colors.textLight) : Color(hex: Theme.Colors.textMuted))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(Color(hex: Theme.Colors.textMuted))
                }
                
                Spacer()
                
                Text("\(Int(value * 100))%")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(value > 0 ? color : Color(hex: Theme.Colors.textMuted).opacity(0.5))
                    .frame(width: 40, alignment: .trailing)
            }
            
            // Custom Slider Component
            GeometryReader { geo in
                let width = geo.size.width
                
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 2)
                    
                    // Fill
                    Capsule()
                        .fill(color.opacity(value > 0 ? 0.8 : 0.0))
                        .frame(width: width * CGFloat(value), height: 2)
                    
                    // Thumb
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(x: (width * CGFloat(value)) - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let percentage = min(max(0, value.location.x / width), 1)
                                    self.value = Float(percentage)
                                }
                        )
                }
            }
            .frame(height: 16)
        }
        .padding(20)
        .background(Color(hex: Theme.Colors.surfaceDark).opacity(0.3))
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(.horizontal, 16)
        )
    }
}

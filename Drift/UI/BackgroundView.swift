import SwiftUI

struct BackgroundView: View {
    let mode: BrainwaveState
    
    var gradientColors: [Color] {
        switch mode {
        case .delta:
            return [Color(hex: "#1c1b19"), Color(hex: "#2c2a26"), Color(hex: "#1c1b19")]
        case .theta:
            return [Color(hex: Theme.Colors.backgroundDark), Color(hex: "#3d3a36"), Color(hex: Theme.Colors.backgroundDark)]
        case .alpha:
            // Entering Space: Deep Blue/Indigo
            return [
                Color(hex: Theme.Colors.spaceDark),
                Color(hex: Theme.Colors.spaceBlue),
                Color(hex: Theme.Colors.spaceDark)
            ]
        case .beta:
            // Deep Space: Void with Nebula Purple accents
            return [
                Color(hex: Theme.Colors.spaceDark),
                Color(hex: Theme.Colors.nebulaPurple).opacity(0.3),
                Color(hex: Theme.Colors.spaceDark)
            ]
        }
    }
    
    var body: some View {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
}

enum BrainwaveState: String, CaseIterable, Identifiable {
    case delta = "Delta"
    case theta = "Theta"
    case alpha = "Alpha"
    case beta = "Beta"
    
    var id: String { rawValue }
    
    var centerFrequency: Float {
        switch self {
        case .delta: return 2.0
        case .theta: return 6.0
        case .alpha: return 10.0
        case .beta:  return 20.0
        }
    }
    
    var displayLabel: String {
        return String(format: "%.1f Hz", centerFrequency)
    }
    
    var rangeDescription: String {
        switch self {
        case .delta: return "0.5 - 4 Hz"
        case .theta: return "4 - 8 Hz"
        case .alpha: return "8 - 12 Hz"
        case .beta:  return "12 - 30 Hz"
        }
    }
    
    var description: String {
        switch self {
        case .delta: return "Deep Sleep"
        case .theta: return "Deep Meditation"
        case .alpha: return "Relaxation"
        case .beta: return "Focus & Alertness"
        }
    }
}

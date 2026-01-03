import SwiftUI

struct Theme {
    struct Colors {
        static let primary = "#8f9e8a" // Muted Sage Green
        static let secondary = "#a88b7d" // Soft Earth Brown
        static let backgroundLight = "#f2f0eb" // Warm Off-white
        static let backgroundDark = "#1c1b19" // Deep Warm Charcoal
        static let surfaceDark = "#262522" // Lighter Warm Charcoal
        static let textMuted = "#9ca3af"
        static let textLight = "#e3e0d6"
        
        // Space Theme
        static let spaceDark = "#0f1219" // Deep Void
        static let spaceBlue = "#1e293b" // Slate Blue
        static let nebulaPurple = "#4c1d95" // Deep Purple
        static let starlight = "#94a3b8" // Blue-ish Grey
        
        // Gradient Colors
        static let deltaGradientMiddle = "#2c2a26"
        static let thetaGradientMiddle = "#3d3a36"
    }

    struct Typography {
        // Use empty to trigger system font fallback logic in View
        // Or we could return ".system(size: ... design: .rounded)" directly if this were a View modifier, 
        // but since we return String, let's keep it simple.
        // Actually, the warning comes from applying .fontWeight to a specific named font that doesn't have that weight.
        // We will switch MainView to use .system(design: .rounded) instead of this custom string.
        static let displayFont = "System-Rounded" // Placeholder, logic will change in MainView
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

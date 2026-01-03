import SwiftUI

/// The central Design System for Drift.
///
/// This struct acts as the "Single Source of Truth" for all visual constants found in the app.
/// By centralizing these values, we ensure:
/// 1. **Consistency**: The same "Sage Green" is used everywhere.
/// 2. **Maintainability**: Changing a color means changing it here, once.
/// 3. **Theming**: Easy updates to the entire app's mood.
struct Theme {
    
    /// Color Palette
    ///
    /// The app uses a "nature-inspired dark mode" palette.
    /// - **Primary**: Natural tones (Sage, Earth) for active elements.
    /// - **Background**: Deep, warm charcoals instead of pure black for reduced eye strain.
    struct Colors {
        // MARK: - Brand Colors
        static let primary = "#8f9e8a"      // Muted Sage Green - Used for active states/waves
        static let secondary = "#a88b7d"    // Soft Earth Brown - Accent color
        
        // MARK: - Surfaces (Dark Mode)
        static let backgroundDark = "#1c1b19" // Deep Warm Charcoal - Main background
        static let surfaceDark = "#262522"    // Lighter Charcoal - For cards/sheets
        
        // MARK: - Typography Colors
        static let textLight = "#e3e0d6"      // Warm Off-white - Primary text
        static let textMuted = "#9ca3af"      // Grey - Secondary/Label text
        
        // MARK: - Atmosphere / Gradient Palettes
        // specific colors for the dynamic background gradients per state
        static let deltaGradientMiddle = "#2c2a26"
        static let thetaGradientMiddle = "#3d3a36"
        
        // MARK: - Space Theme (Visuals)
        static let spaceDark = "#0f1219"     // Deep Void
        static let spaceBlue = "#1e293b"     // Slate Blue
        static let nebulaPurple = "#4c1d95"  // Deep Purple
        static let starlight = "#94a3b8"     // Star/Particle color
    }
}

// MARK: - Color Hex Extension
// Provides a convenient way to initialize SwiftUI Colors from Hex strings.
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

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
// Use: Color(hex: "#FF0000")
extension Color {
    init(hex: String) {
        // 1. Clean the string (remove "#" and any spaces)
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        // 2. Scan the string into a 64-bit integer
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        // 3. Extract correct components based on length
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // 12-bit RGB (e.g. "FFF")
            // Expand 4-bits to 8-bits by multiplying by 17 (0xF -> 0xFF)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // 24-bit RGB (e.g. "FF0000")
            // Bitwise shift (>>) to move bits to right, then Mask (&) to isolate last 8 bits
            // R: Top 8 bits, G: Middle 8 bits, B: Bottom 8 bits
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // 32-bit ARGB (e.g. "FFFF0000")
            // Same logic, but with Alpha at top 8 bits
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        // 4. Normalize to 0.0 - 1.0 (SwiftUI standard)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

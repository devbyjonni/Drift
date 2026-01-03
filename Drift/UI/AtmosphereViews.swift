import SwiftUI

struct SpaceView: View {
    // MARK: - Configuration
    var intensity: Double // 0.0 to 1.0
    
    // MARK: - State
    @State private var pulse: CGFloat = 1.0
    @State private var stars: [Star] = []
    
    var body: some View {
        ZStack {
            // 1. Pulsing "Breathing" Glow
            // Creates a subtle atmospheric change over time
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: Theme.Colors.primary).opacity(0.1 * intensity),
                    Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 200 * pulse
            )
            .scaleEffect(pulse)
            .onAppear {
                setupAnimation()
            }
            
            // 2. Static Star Field
            // Generated once on appear to prevent "flickering" redraws
            GeometryReader { geo in
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white.opacity(star.opacity))
                        .frame(width: star.size)
                        .position(
                            x: star.x * geo.size.width,
                            y: star.y * geo.size.height
                        )
                }
            }
        }
        .onAppear {
            generateStars()
        }
    }
    
    // MARK: - Formatting & Logic
    
    private func setupAnimation() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulse = 1.5
        }
    }
    
    private func generateStars() {
        // Create ~20 stars based on intensity
        let count = Int(20 * intensity)
        stars = (0..<count).map { _ in
            Star(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.1...0.4)
            )
        }
    }
}

// MARK: - Models

struct Star: Identifiable {
    let id = UUID()
    let x: Double // 0-1 normalized position
    let y: Double // 0-1 normalized position
    let size: CGFloat
    let opacity: Double
}

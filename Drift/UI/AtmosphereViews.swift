import SwiftUI

struct SpaceView: View {
    @State private var pulse: CGFloat = 1.0
    var intensity: Double // 0.0 to 1.0
    
    var body: some View {
        ZStack {
            // Pulsing Glow
            RadialGradient(gradient: Gradient(colors: [
                Color(hex: Theme.Colors.primary).opacity(0.1 * intensity),
                Color.clear
            ]), center: .center, startRadius: 10, endRadius: 200 * pulse)
            .scaleEffect(pulse)
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    pulse = 1.5
                }
            }
            // Abstract Stars
            GeometryReader { geo in
                ForEach(0..<Int(20 * intensity), id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.4)))
                        .frame(width: CGFloat.random(in: 1...3))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
            }
        }
    }
}

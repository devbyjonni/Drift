import SwiftUI

struct RainView: View {
    var intensity: Double // 0.0 to 1.0
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            
            // Draw random rain drops
            // In a real app complexity: use a TimelineView and animate drops falling
            // For minimalist entrainment: static falling lines or simple animation is fine
            // We'll use a predictable chaos for visualization
            
            for _ in 0..<Int(intensity * 100) {
                let x = Double.random(in: 0...width)
                let y = Double.random(in: 0...height)
                let len = Double.random(in: 10...30)
                
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x, y: y + len))
                }
                context.stroke(path, with: .color(.white.opacity(0.1 + intensity * 0.2)), lineWidth: 1)
            }
        }
    }
}

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

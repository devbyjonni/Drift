import SwiftUI

struct WaveView: View, Animatable {
    var frequency: Double
    var amplitude: Double
    
    // Allow SwiftUI to interpolate frequency and amplitude changes
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(frequency, amplitude) }
        set {
            frequency = newValue.first
            amplitude = newValue.second
        }
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let midHeight = height / 2
                
                // Use timeline date for continuous scrolling phase
                // Constant speed of 2.0 prevents phase jumps
                let time = timeline.date.timeIntervalSinceReferenceDate
                let globalPhase = time * 2.0
                
                var path = Path()
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin((relativeX * frequency * .pi * 2) - globalPhase)
                    let y = midHeight + sine * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                context.stroke(path, with: .color(Color(hex: Theme.Colors.primary)), lineWidth: 2)
            }
        }
    }
}

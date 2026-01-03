import SwiftUI

/// A high-performance sine wave visualization that supports smooth animation.
///
/// This view uses `Canvas` for efficient drawing and conforms to `Animatable`
/// to allow SwiftUI to interpolate `frequency` and `amplitude` changes over time
/// (e.g., during `.easeInOut` transitions).
struct WaveView: View, Animatable {
    /// The number of wave cycles visible across the width of the view.
    var frequency: Double
    
    /// The height of the wave peaks (in points).
    /// When set to 0, the wave flattens to a straight line.
    var amplitude: Double
    
    // MARK: - Animatable Protocol
    // This is the "magic" that allows SwiftUI to animate our custom drawing properties.
    // When you apply `.animation()` to this view, SwiftUI sets this property frame-by-frame,
    // interpolating from the old value to the new value.
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(frequency, amplitude) }
        set {
            frequency = newValue.first
            amplitude = newValue.second
        }
    }
    
    var body: some View {
        // TimelineView is essential here because the wave needs to "scroll" (change phase)
        // continuously efficiently, even if frequency/amplitude are static.
        // It provides a new `date` every frame (approx 60/120fps).
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let midHeight = height / 2
                
                // 1. Calculate Phase Shift (Scrolling)
                // We use the current time to offset the wave horizontally.
                // Multiplying by a constant speed (2.0) ensures the scrolling speed
                // remains constant, preventing visual "jumps" when stopping/starting.
                let time = timeline.date.timeIntervalSinceReferenceDate
                let globalPhase = time * 2.0
                
                var path = Path()
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                // 2. Draw the Sine Wave
                // "stride" allows us to skip pixels for performance (drawing every 2nd pixel).
                // A lower stride (1) is higher quality but more expensive; 2 is a good balance.
                for x in stride(from: 0, through: width, by: 2) {
                    // Normalize x to 0.0 - 1.0 range
                    let relativeX = x / width
                    
                    // The Math:
                    // sin(angle)
                    // angle = (position * freq * 2pi) - phaseOffset
                    let sine = sin((relativeX * frequency * .pi * 2) - globalPhase)
                    
                    // project y: center + (value * height)
                    let y = midHeight + sine * amplitude
                    
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // 3. Stroke the Path
                context.stroke(path, with: .color(Color(hex: Theme.Colors.primary)), lineWidth: 2)
            }
        }
    }
}

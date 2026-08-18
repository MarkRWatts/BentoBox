import SwiftUI

/// A single stroked progress ring. Deliberately plain `Shape` drawing rather than Swift Charts —
/// callers that need many small instances at once (a week strip, a month grid) pay Charts' full
/// per-instance layout/accessibility overhead for no benefit at that size, and stacking two rings
/// concentrically is just two `Circle`s rather than coordinating two `SectorMark` series sharing
/// one canvas. Charts stays the right tool for the app's few large, single-instance rings/pies
/// (`CalorieSummaryRingView`, the macro pie) where its built-in legend/annotation machinery earns
/// its keep.
struct RingProgressView: View {
    /// 0...1, pre-clamped by the caller.
    let progress: Double
    let lineWidth: CGFloat
    let trackColor: Color
    let progressColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    RingProgressView(progress: 0.7, lineWidth: 10, trackColor: .secondary.opacity(0.15), progressColor: .accentColor)
        .frame(width: 100, height: 100)
        .padding()
}

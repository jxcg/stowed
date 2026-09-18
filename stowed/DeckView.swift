import SwiftUI

// A pile of cards (decision 22). The top trip in full, up to four more peeking out behind it
// at a slight angle. Swipe the top card away to bring the next one forward.
struct DeckView<Card: View>: View {
    let trips: [Trip]
    @ViewBuilder let card: (Trip) -> Card
    @State private var topIndex = 0
    @State private var drag: CGSize = .zero

    private static var maxVisible: Int { 5 }

    // From the top of the pile round to the one before it, capped for drawing.
    private var visible: [Trip] {
        guard !trips.isEmpty else { return [] }
        let start = topIndex % trips.count
        return Array((trips[start...] + trips[..<start]).prefix(Self.maxVisible))
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(Array(visible.enumerated().reversed()), id: \.element.id) { depth, trip in
                    card(trip)
                        .scaleEffect(1 - CGFloat(depth) * 0.04)
                        .rotationEffect(.degrees(Double(depth) * (depth.isMultiple(of: 2) ? 2.5 : -2.5)))
                        .offset(y: CGFloat(depth) * -14)
                        .offset(depth == 0 ? drag : .zero)
                        .rotationEffect(depth == 0 ? .degrees(Double(drag.width) / 20) : .zero)
                        .allowsHitTesting(depth == 0)
                }
            }
            // Deeper pile, deeper shadow.
            .shadow(color: .black.opacity(0.08 + 0.04 * Double(min(trips.count, Self.maxVisible))), radius: 12, y: 8)
            .highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { drag = $0.translation }
                    .onEnded { value in
                        guard abs(value.translation.width) > 100, trips.count > 1 else {
                            withAnimation(.bouncy) { drag = .zero }
                            return
                        }
                        withAnimation(.snappy) { drag = CGSize(width: value.translation.width * 4, height: 0) }
                        withAnimation(.snappy.delay(0.15)) {
                            topIndex += 1
                            drag = .zero
                        }
                    }
            )
            .padding(.top, 40)

            if trips.count > 1 {
                Text("\(trips.count) trips. Swipe to see the next.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

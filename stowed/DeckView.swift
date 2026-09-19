import SwiftUI

// A pack of cards, stacked imperfectly (decisions 22, 27). Most recent on top. Swipe the top
// card either way to reach the next trip; the pile wraps round.
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
                    let lie = Lie(trip: trip, depth: depth)
                    card(trip)
                        .shadow(color: .black.opacity(0.22), radius: 5, x: lie.x / 2, y: 4)
                        .scaleEffect(1 - CGFloat(depth) * 0.02)
                        .rotationEffect(.degrees(lie.angle))
                        .offset(x: lie.x, y: lie.y)
                        .offset(depth == 0 ? drag : .zero)
                        .rotationEffect(depth == 0 ? .degrees(Double(drag.width) / 20) : .zero)
                        .allowsHitTesting(depth == 0)
                }
            }
            // The pile as a whole sits heavier the more cards are in it.
            .shadow(color: .black.opacity(0.06 * Double(min(trips.count, Self.maxVisible))), radius: 18, y: 12)
            .highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { drag = $0.translation }
                    .onEnded { value in
                        guard abs(value.translation.width) > 100, trips.count > 1 else {
                            withAnimation(.bouncy) { drag = .zero }
                            return
                        }
                        // Either direction takes the top card off and reveals the next.
                        withAnimation(.snappy) { drag = CGSize(width: value.translation.width * 4, height: 0) }
                        withAnimation(.snappy.delay(0.15)) {
                            topIndex += 1
                            drag = .zero
                        }
                    }
            )
            .padding(.top, 40)

            if trips.count > 1 {
                Text("\(trips.count) trips. Swipe either way for the next.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

// How one card happens to lie in the pile. Fixed per trip and depth, so the pack never
// reshuffles itself while you look at it.
private struct Lie {
    let angle: Double
    let x: CGFloat
    let y: CGFloat

    init(trip: Trip, depth: Int) {
        guard depth > 0 else {
            angle = 0; x = 0; y = 0
            return
        }
        var random = SeededRandom(seed: trip.textureSeed)
        let spread = CGFloat(depth)
        angle = (random.unit() * 2 - 1) * (2.5 + Double(depth) * 1.6)
        x = (random.unit() * 2 - 1) * (7 + spread * 7)
        y = -spread * 13 + (random.unit() * 2 - 1) * 5
    }
}

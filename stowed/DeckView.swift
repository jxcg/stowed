import SwiftUI

// A pack of cards, stacked imperfectly (decisions 22, 27). Most recent on top. Swipe the top
// card either way to reach the next trip; the pile wraps round.
struct DeckView<Card: View>: View {
    let trips: [Trip]
    @ViewBuilder let card: (Trip) -> Card
    @State private var topIndex = 0
    @State private var drag: CGSize = .zero
    // How hard it is being thrown, which the top card reads to show its printing.
    @State private var reveal: Double = 0
    @Environment(\.cardTilt) private var tilt
    // Where the incoming card starts from when you travel by the dots.
    @State private var entry: CGSize = .zero
    @AppStorage("motionEffect") private var motionEffect = false

    private static var maxVisible: Int { 5 }

    // From the top of the pile round to the one before it, capped for drawing.
    private var visible: [Trip] {
        guard !trips.isEmpty else { return [] }
        let start = topIndex % trips.count
        return Array((trips[start...] + trips[..<start]).prefix(Self.maxVisible))
    }

    // Travelling by the dots fans the next card in from the side it came from, rather than
    // swapping it in place. Held to the motion setting: with that off, it simply changes.
    private func travel(to index: Int) {
        guard index != topIndex % max(1, trips.count) else { return }
        guard motionEffect else {
            topIndex = index
            return
        }
        let forward = index > topIndex % max(1, trips.count)
        // Put the incoming card off to one side without animating that jump...
        var placement = Transaction()
        placement.disablesAnimations = true
        withTransaction(placement) {
            topIndex = index
            entry = CGSize(width: forward ? 300 : -300, height: 24)
        }
        // ...then let it settle, which is the part you see.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) { entry = .zero }
    }

    var body: some View {
        // The dots are laid down first so they sit behind the pile: a card dragged low passes
        // over them rather than under.
        ZStack(alignment: .bottom) {
            if trips.count > 1 {
                DeckDots(count: trips.count, index: topIndex % trips.count) { travel(to: $0) }
            }

            VStack(spacing: 16) {
                ZStack {
                ForEach(Array(visible.enumerated().reversed()), id: \.element.id) { depth, trip in
                    let lie = Lie(trip: trip, depth: depth)
                    card(trip)
                        .shadow(color: .black.opacity(0.22), radius: 5, x: lie.x / 2, y: 4)
                        .scaleEffect(1 - CGFloat(depth) * 0.02)
                        .rotationEffect(.degrees(lie.angle))
                        .offset(x: lie.x, y: lie.y)
                        .offset(depth == 0 ? CGSize(width: drag.width + entry.width,
                                                    height: drag.height + entry.height) : .zero)
                        .rotationEffect(depth == 0 ? .degrees(Double(drag.width + entry.width) / 20) : .zero)
                        .environment(\.cardReveal, depth == 0 ? reveal : 0)
                        // Only the card on top answers the phone's movement.
                        .environment(\.cardTilt, depth == 0 ? tilt : .zero)
                        .allowsHitTesting(depth == 0)
                }
            }
                // The pile as a whole sits heavier the more cards are in it.
                .shadow(color: .black.opacity(0.06 * Double(min(trips.count, Self.maxVisible))), radius: 18, y: 12)
                .highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { value in
                        drag = value.translation
                        // Under the hand it glimpses; it takes a real throw to light it up.
                        let effortSoFar = hypot(value.predictedEndTranslation.width - value.translation.width,
                                                value.predictedEndTranslation.height - value.translation.height)
                        reveal = min(0.85, effortSoFar / 420 + abs(value.translation.width) / 900)
                    }
                    .onEnded { value in
                        // How hard it was thrown, not just how far. A flick and a shove should
                        // not leave at the same speed.
                        let throwSpeed = hypot(value.predictedEndTranslation.width - value.translation.width,
                                               value.predictedEndTranslation.height - value.translation.height)
                        let committed = abs(value.translation.width) > 100 || throwSpeed > 180
                        guard committed, trips.count > 1 else {
                            withAnimation(.bouncy) { drag = .zero }
                            withAnimation(.easeOut(duration: 0.4)) { reveal = 0 }
                            return
                        }
                        // Carry the throw through: a harder swipe flies further and settles sooner.
                        let effort = min(1.6, 0.35 + throwSpeed / 900)
                        let exit = value.predictedEndTranslation.width == 0
                            ? value.translation.width * 3
                            : value.predictedEndTranslation.width * 1.6
                        withAnimation(.interpolatingSpring(stiffness: 120 + effort * 130, damping: 18)) {
                            drag = CGSize(width: exit, height: value.predictedEndTranslation.height * 0.6)
                        }
                        // Flash of everything on the way out, then gone.
                        withAnimation(.easeOut(duration: 0.12)) { reveal = min(1, 0.4 + effort * 0.6) }
                        withAnimation(.snappy(duration: 0.34 - Double(effort) * 0.12).delay(0.08)) {
                            topIndex += 1
                            drag = .zero
                        }
                        withAnimation(.easeOut(duration: 0.45).delay(0.1)) { reveal = 0 }
                    }
                )
                .padding(.top, 40)

                // Holds the dots' place so nothing shifts when they are behind the cards.
                Color.clear.frame(height: 22)
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

// A run of dots you can drag along to travel the deck, like a photo pager. However many trips
// there are, only a window of dots is drawn; the rest exist, they just are not painted.
private struct DeckDots: View {
    let count: Int
    let index: Int
    let move: (Int) -> Void

    private static var window: Int { 9 }

    // The slice of dots around wherever you are.
    private var range: Range<Int> {
        guard count > Self.window else { return 0..<count }
        let start = min(max(0, index - Self.window / 2), count - Self.window)
        return start..<(start + Self.window)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 7) {
                ForEach(range, id: \.self) { dot in
                    let here = dot == index
                    // Dots shrink toward the ends, so the run looks like it continues past them.
                    let edge = min(dot - range.lowerBound, range.upperBound - 1 - dot)
                    Circle()
                        .fill(here ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: here ? 8 : max(3, 6 - CGFloat(max(0, 1 - edge)) * 2),
                               height: here ? 8 : max(3, 6 - CGFloat(max(0, 1 - edge)) * 2))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Hold at either end and it keeps travelling.
                        let reach = max(1, geometry.size.width)
                        let share = min(max(0, value.location.x / reach), 1)
                        move(Int(round(share * Double(count - 1))))
                    }
            )
            .animation(.snappy(duration: 0.2), value: index)
        }
        .frame(height: 22)
        .accessibilityLabel("Trip \(index + 1) of \(count)")
        .accessibilityAdjustableAction { direction in
            move(direction == .increment ? min(count - 1, index + 1) : max(0, index - 1))
        }
    }
}

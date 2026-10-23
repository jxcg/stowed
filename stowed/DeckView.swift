import SwiftUI

// A pack of cards, stacked imperfectly (decisions 22, 27). Most recent on top. Swipe the top
// card either way and it goes to the bottom of the pack, like a real deck.
struct DeckView<Card: View>: View {
    let trips: [Trip]
    @ViewBuilder let card: (Trip) -> Card
    @State private var topIndex = 0
    @State private var drag: CGSize = .zero
    // How hard it is being thrown, which the top card reads to show its printing.
    @State private var reveal: Double = 0
    @Environment(\.cardTilt) private var tilt
    @AppStorage("motionEffect") private var motionEffect = false

    private static var maxVisible: Int { 5 }

    // The cards drawn, top first. With a big pack, the bottom slot is always the card that went
    // under last, so a card you swipe away is seen landing at the bottom, not vanishing.
    private var visibleTrips: [Trip] {
        let count = trips.count
        guard count > 0 else { return [] }
        let start = topIndex % count
        let shown = min(count, Self.maxVisible)
        // Only the cards drawn are looked up, however big the pack.
        var drawn = (0..<shown).map { trips[(start + $0) % count] }
        if count > Self.maxVisible { drawn[shown - 1] = trips[(start + count - 1) % count] }
        return drawn
    }

    // The dots move the pack a card at a time, the way a swipe does: forward tucks the top card
    // under, back brings the bottom one up. With the motion setting off it simply changes.
    private func travel(to index: Int) {
        guard trips.indices.contains(index), index != topIndex % trips.count else { return }
        guard motionEffect else {
            topIndex = index
            return
        }
        withAnimation(.snappy(duration: 0.3)) { topIndex = index }
    }

    var body: some View {
        // The dots are laid down first so they sit behind the pile: a card dragged low passes
        // over them rather than under.
        ZStack(alignment: .bottom) {
            if trips.count > 1 {
                DeckDots(count: trips.count, index: topIndex % trips.count, move: travel)
            }

            VStack(spacing: 16) {
                ZStack {
                    ForEach(Array(visibleTrips.enumerated()), id: \.element.id) { depth, trip in
                        stackedCard(trip, depth: depth)
                    }
                }
                // The pile as a whole sits heavier the more cards are in it.
                .shadow(color: .black.opacity(0.06 * Double(min(trips.count, Self.maxVisible))), radius: 18, y: 12)
                .highPriorityGesture(swipeGesture)
                .padding(.top, 40)

                // Holds the dots' place so nothing shifts when they are behind the cards.
                Color.clear.frame(height: 22)
            }
        }
        .padding()
    }

    private func stackedCard(_ trip: Trip, depth: Int) -> some View {
        let placement = CardPlacement(trip: trip, depth: depth)
        return card(trip)
            .shadow(color: .black.opacity(0.22), radius: 5, x: placement.x / 2, y: 4)
            .scaleEffect(1 - CGFloat(depth) * 0.02)
            .rotationEffect(.degrees(placement.angle))
            .offset(x: placement.x, y: placement.y)
            .offset(depth == 0 ? drag : .zero)
            .rotationEffect(depth == 0 ? .degrees(Double(drag.width) / 20) : .zero)
            // Depth changes at once while position animates, so a card sent to the bottom
            // passes behind the pack on its way there. Stated outright, not left to array order,
            // so it also holds for a card animating out of the drawn set.
            .zIndex(-Double(depth))
            .environment(\.cardReveal, depth == 0 ? reveal : 0)
            // Only the card on top answers the phone's movement.
            .environment(\.cardTilt, depth == 0 ? tilt : .zero)
            .environment(\.cardLightOffset, depth == 0 ? drag : .zero)
            .allowsHitTesting(depth == 0)
    }

    private var swipeGesture: some Gesture {
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
    }
}

// How one card happens to lie in the pile. Fixed per trip and depth, so the pack never
// reshuffles itself while you look at it.
private struct CardPlacement {
    let angle: Double
    let x: CGFloat
    let y: CGFloat

    init(trip: Trip, depth: Int) {
        guard depth > 0 else {
            angle = 0
            x = 0
            y = 0
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

    // Where this drag began, and the dot under it. Keyed by the touch-down point so a drag the
    // system cancelled (no onEnded) cannot leak its anchor into the next one.
    @State private var gestureStart: (at: CGPoint, dot: Int)?

    private static var window: Int { 9 }

    // The slice of dots around wherever you are.
    private var range: Range<Int> {
        guard count > Self.window else { return 0..<count }
        let start = min(max(0, index - Self.window / 2), count - Self.window)
        return start..<(start + Self.window)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(range, id: \.self) { dot in
                    let here = dot == index
                    // Dots shrink toward the ends, so the run looks like it continues past them.
                    let edge = min(dot - range.lowerBound, range.upperBound - 1 - dot)
                    Circle()
                        .fill(here ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: here ? 8 : max(3, 6 - CGFloat(max(0, 1 - edge)) * 2),
                               height: here ? 8 : max(3, 6 - CGFloat(max(0, 1 - edge)) * 2))
                        .frame(width: DeckDotTrack.pitch)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let track = DeckDotTrack(count: count, visible: range, width: geometry.size.width)
                        // Anchor once: changing the selected dot can shift the visible window.
                        if gestureStart?.at != value.startLocation {
                            gestureStart = (value.startLocation, track.index(at: value.startLocation.x))
                        }
                        let start = gestureStart?.dot ?? index
                        move(Int(track.position(from: start, translation: value.translation.width).rounded()))
                    }
                    .onEnded { _ in gestureStart = nil }
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

// Fixed dot slots keep hit positions stable when the selected circle grows.
struct DeckDotTrack {
    static let pitch: CGFloat = 15
    let count: Int
    let visible: Range<Int>
    let width: CGFloat

    func index(at x: CGFloat) -> Int {
        let firstCenter = (width - CGFloat(visible.count) * Self.pitch) / 2 + Self.pitch / 2
        let slot = Int(((x - firstCenter) / Self.pitch).rounded())
        return min(visible.upperBound - 1, max(visible.lowerBound, visible.lowerBound + slot))
    }

    func position(from start: Int, translation: CGFloat) -> Double {
        min(Double(count - 1), max(0, Double(start) + Double(translation / Self.pitch)))
    }
}

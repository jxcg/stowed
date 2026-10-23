import SwiftUI

// The trips as a pack of cards (decisions 22, 27).
// In: the trips, newest first, and how to draw one card.
// Out: up to five cards stacked a little untidily, newest on top, with dots underneath.
// Swipe the top card either way and it goes to the bottom of the pack, like a real deck.
struct DeckView<Card: View>: View {
    let trips: [Trip]
    @ViewBuilder let card: (Trip) -> Card
    @State private var topIndex = 0
    @State private var drag: CGSize = .zero
    // How hard it is being thrown, which the top card reads to show its printing.
    @State private var reveal: Double = 0
    // True while a thrown card is still flying off, so a second grab cannot catch it mid-air.
    @State private var throwing = false
    @AppStorage("motionEffect") private var motionEffect = false

    private static var maxVisible: Int { 5 }

    // Which cards to draw.
    // In: all the trips, and which one is on top.
    // Out: at most five trips, top card first. With more than five, the last one is the card
    // that went under most recently, so a swiped card is seen landing at the bottom.
    private var visibleTrips: [Trip] {
        deckDrawOrder(count: trips.count, top: topIndex, limit: Self.maxVisible).map { trips[$0] }
    }

    // Called by the dots.
    // In: the trip the dots now point at.
    // Out: that trip is on top. Going forward, the old top card tucks under the pack; going
    // back, the bottom card comes up. Animated only when the motion setting is on.
    private func travel(to index: Int) {
        guard trips.indices.contains(index), index != topIndex % trips.count else { return }
        withAnimation(motionEffect ? .snappy(duration: 0.3) : nil) { topIndex = index }
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

    // One card in the pack.
    // In: the trip, and its depth (0 is the top card, 1 the one under it, and so on).
    // Out: the card, nudged and tilted into its place in the pack. Only the top card follows
    // your finger, reacts to the phone's tilt, and can be tapped.
    private func stackedCard(_ trip: Trip, depth: Int) -> some View {
        let placement = CardPlacement(trip: trip, depth: depth)
        return card(trip)
            .shadow(color: .black.opacity(0.22), radius: 5, x: placement.x / 2, y: 4)
            .scaleEffect(1 - CGFloat(depth) * 0.02)
            .rotationEffect(.degrees(placement.angle))
            .offset(x: placement.x, y: placement.y)
            .offset(depth == 0 ? drag : .zero)
            .rotationEffect(depth == 0 ? .degrees(Double(drag.width) / 20) : .zero)
            // Deeper cards draw further back. The depth changes instantly but the position
            // animates, so a swiped card slides behind the pack on its way to the bottom.
            .zIndex(-Double(depth))
            .environment(\.cardReveal, depth == 0 ? reveal : 0)
            // Only the card on top answers the phone's movement. The tilt is zeroed for the rest
            // here, without the deck reading it, so a tilt change redraws the top card alone.
            .transformEnvironment(\.cardTilt) { if depth > 0 { $0 = .zero } }
            .environment(\.cardLightOffset, depth == 0 ? drag : .zero)
            .allowsHitTesting(depth == 0)
    }

    // Dragging the top card.
    // In: your finger's movement, and how fast it was going when you let go.
    // Out: a short drag springs back. A long drag or a flick throws the card off, harder
    // throws flying further, and it then tucks in at the bottom of the pack.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard !throwing else { return }
                drag = value.translation
                // Under the hand it glimpses; it takes a real throw to light it up.
                let effortSoFar = hypot(value.predictedEndTranslation.width - value.translation.width,
                                        value.predictedEndTranslation.height - value.translation.height)
                reveal = min(0.85, effortSoFar / 420 + abs(value.translation.width) / 900)
            }
            .onEnded { value in
                guard !throwing else { return }
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
                // However gentle, it always travels far enough to clear the pack.
                let effort = min(1.6, 0.35 + throwSpeed / 900)
                let flung = value.predictedEndTranslation.width == 0
                    ? value.translation.width * 3
                    : value.predictedEndTranslation.width * 1.6
                let exit = (flung < 0 ? -1 : 1) * max(abs(flung), 420)
                throwing = true
                // Flash of everything on the way out.
                withAnimation(.easeOut(duration: 0.12)) { reveal = min(1, 0.4 + effort * 0.6) }
                // Two steps, one after the other: first the card flies off while still on top,
                // then it tucks in at the bottom. Run in one go, the second would cancel the first.
                withAnimation(.interpolatingSpring(stiffness: 120 + effort * 130, damping: 18)) {
                    drag = CGSize(width: exit, height: value.predictedEndTranslation.height * 0.6)
                } completion: {
                    withAnimation(.snappy(duration: 0.34 - Double(effort) * 0.12)) {
                        topIndex += 1
                        drag = .zero
                        reveal = 0
                    }
                    throwing = false
                }
            }
    }
}

// Which trips to draw, by their position in the list.
// In: how many trips there are, which one is on top (any whole number; it wraps round), and
// how many cards can be drawn.
// Out: positions, top card first. If the pack is bigger than the limit, the last one drawn is
// the card just before the top in the list: the one that went under most recently.
func deckDrawOrder(count: Int, top: Int, limit: Int) -> [Int] {
    guard count > 0, limit > 0 else { return [] }
    let start = top % count
    // Only the cards drawn are looked up, so a big pack costs no more than a small one.
    var drawn = (0..<min(count, limit)).map { (start + $0) % count }
    if count > limit { drawn[limit - 1] = (start + count - 1) % count }
    return drawn
}

// How far one card sits out of line in the pack.
// In: the trip, and its depth (0 is the top card).
// Out: a small angle and offset. The top card is straight; deeper cards sit higher and more
// askew. The same trip at the same depth always gets the same answer, so the pack never
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

// The dots under the pack, like a photo pager.
// In: how many trips there are, which one is on top, and what to call when you pick another.
// Out: up to nine dots, the current one larger. Tap a dot, or drag along them, to move.
private struct DeckDots: View {
    let count: Int
    let index: Int
    let move: (Int) -> Void

    // Where this drag began, and the dot under it. Keyed by the touch-down point so a drag the
    // system cancelled (no onEnded) cannot leak its anchor into the next one.
    @State private var gestureStart: (at: CGPoint, dot: Int)?

    private static var window: Int { 9 }

    // Which dots to draw: up to nine, centred on the current trip where possible.
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
                        // Remember the dot the drag started on. Moving changes which dots are
                        // drawn, so measuring from the finger's current spot would drift.
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

// Turns finger positions on the dots into trips. Every dot gets the same 15pt slot, so the
// spots you touch don't move when the current dot grows.
struct DeckDotTrack {
    static let pitch: CGFloat = 15
    let count: Int
    let visible: Range<Int>
    let width: CGFloat

    // In: where you touched, across the dots' width.
    // Out: the trip under that spot, or the nearest drawn one if you touched past either end.
    func index(at x: CGFloat) -> Int {
        let firstCenter = (width - CGFloat(visible.count) * Self.pitch) / 2 + Self.pitch / 2
        let slot = Int(((x - firstCenter) / Self.pitch).rounded())
        return min(visible.upperBound - 1, max(visible.lowerBound, visible.lowerBound + slot))
    }

    // In: the trip the drag started on, and how far the finger has moved since.
    // Out: where that lands, one trip per 15pt and kept within the first and last trip.
    // It can fall between two trips; the caller rounds it.
    func position(from start: Int, translation: CGFloat) -> Double {
        min(Double(count - 1), max(0, Double(start) + Double(translation / Self.pitch)))
    }
}

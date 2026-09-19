import SwiftUI

// Wallet: a few trips held together, the rest behind an ellipsis (issue #60, exploratory).
// Two collapsed layouts to compare; both open into the same horizontal spread.
struct WalletView<Card: View>: View {
    enum Layout: String, CaseIterable { case cascade, fan }

    let trips: [Trip]
    let layout: Layout
    @ViewBuilder let card: (Trip) -> Card
    @State private var expanded = false

    private static var heldCount: Int { 4 }

    private var held: [Trip] { Array(trips.prefix(Self.heldCount)) }
    private var moreCount: Int { max(0, trips.count - Self.heldCount) }

    var body: some View {
        Group {
            if expanded { spread } else { wallet }
        }
        .animation(.snappy(duration: 0.45), value: expanded)
    }

    // MARK: Held. Newest sits in front; older ones show only an edge, oldest behind the ellipsis.
    private var wallet: some View {
        let cascading = layout == .cascade
        let step: CGFloat = cascading ? 104 : 34
        // Drawn back to front: ellipsis, then oldest of the four, ending with the newest in front.
        let slots = held.reversed().enumerated()
        let depth = CGFloat(held.count)

        return ScrollView {
            ZStack(alignment: cascading ? .top : .leading) {
                if moreCount > 0 { more.zIndex(-1) }
                ForEach(Array(slots), id: \.element.id) { index, trip in
                    let slot = CGFloat(index) + (moreCount > 0 ? 1 : 0)
                    card(trip)
                        .scaleEffect(cascading ? 1 : 0.58, anchor: .leading)
                        .offset(x: cascading ? 0 : slot * step, y: cascading ? slot * step : 0)
                        .shadow(color: .black.opacity(0.18), radius: 7, y: 3)
                        .zIndex(Double(index))
                }
            }
            .frame(maxWidth: .infinity, alignment: cascading ? .top : .leading)
            .padding(.bottom, cascading ? depth * step : 0)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
    }

    // The card that stands for everything older. A wide slab in the cascade, a slim tab in the fan.
    private var more: some View {
        let cascading = layout == .cascade
        return Button { expanded = true } label: {
            VStack(spacing: 6) {
                Text("…").font(.system(size: 30, weight: .bold, design: .serif))
                Text("\(moreCount) older").font(.system(.caption2, design: .serif).smallCaps()).tracking(1.5)
                    .fixedSize()
                    .rotationEffect(.degrees(cascading ? 0 : -90))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: cascading ? .infinity : 62, minHeight: cascading ? 0 : 320)
            .padding(.vertical, cascading ? 26 : 12)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, cascading ? 22 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(moreCount) older trips")
    }

    // MARK: Spread. Every trip, swipe across, newest first.
    private var spread: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(trips) { trip in
                        card(trip)
                            .containerRelativeFrame(.horizontal)
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)

            Button("Back to wallet") { expanded = false }
                .font(.footnote)
        }
        .padding(.top, 12)
    }
}

import Observation
import SwiftData
import SwiftUI

// The Trips page as an open book on a folding phone (#117).
// In: a panel and the cards.
// Out: with a fold down the screen, the panel sits left of it and the cards right, nothing under
// the fold itself. With no fold (other iPhones, the outer display, iOS 27.0, a sideways fold)
// it is the cards alone, laid out exactly as before.
struct FoldSpread<Panel: View, Cards: View>: View {
    @ViewBuilder let panel: () -> Panel
    @ViewBuilder let cards: () -> Cards
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fold: CGRect?
    @State private var hinge = HingeReader()

    var body: some View {
        HStack(spacing: 0) {
            if let fold {
                panel()
                    .frame(width: fold.minX)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .modifier(OpensWithHinge(hinge: hinge))
                Color.clear.frame(width: fold.width)
            }
            // Always the last child, so the deck keeps its place (and its state) when the
            // panel comes and goes.
            cards()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .modifier(HingeLight(hinge: hinge))
        }
        .onGeometryChange(for: CGRect?.self, of: Self.verticalFold) { fold = $0 }
        .modifier(HingeWatch(hinge: hinge, isEnabled: !reduceMotion))
        .onChange(of: reduceMotion) { hinge.reset() }
    }

    // Where the fold is, in this view's own coordinates.
    // In: this view's geometry. Out: the fold's frame, or nil if there is no fold, it runs
    // sideways, or it leaves too little room on the left for a panel.
    // Asked for with .includeInactive so a phone lying flat still splits at its crease.
    private nonisolated static func verticalFold(in proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
        guard let frame = regions.first?.frame, frame.height > frame.width, frame.minX >= 240 else { return nil }
        return frame
    }
}

// How far open the phone is. Effects read this; layout never does.
// Its own object so a hinge tick redraws the two small modifiers below, not the whole page.
@Observable
private final class HingeReader {
    // 0 is shut, 180 is flat. Flat until told otherwise, so a phone with no hinge shows no effect.
    private(set) var degrees: Double = 180
    private(set) var isFlat = false

    func update(degrees: Double, isFlat: Bool) {
        self.degrees = degrees
        if self.isFlat != isFlat { self.isFlat = isFlat }
    }

    func reset() { degrees = 180 }

    // 0 at or below `from` degrees, 1 at or above `to`.
    func openness(from: Double, to: Double) -> Double {
        min(1, max(0, (degrees - from) / (to - from)))
    }
}

// Feeds the hinge's angle to the reader. Does nothing before iOS 27.1 or with no hinge.
private struct HingeWatch: ViewModifier {
    let hinge: HingeReader
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange(isEnabled: isEnabled) { _, context in
                guard let now = context.hinge else { return hinge.reset() }
                hinge.update(degrees: now.angle.degrees, isFlat: now.status == .fullyOpen)
            }
        } else {
            content
        }
    }
}

// The panel arrives as the phone opens: clear by a right angle, so it reads fine stood half open.
// One tap of haptic when the phone reaches flat.
private struct OpensWithHinge: ViewModifier {
    let hinge: HingeReader

    func body(content: Content) -> some View {
        let open = hinge.openness(from: 30, to: 90)
        content
            .opacity(open)
            .offset(x: (1 - open) * 24)
            .sensoryFeedback(.impact(weight: .light), trigger: hinge.isFlat) { _, flat in flat }
    }
}

// Folding the phone swings the light across the metal, the same way tilting it does.
// The card itself does not move.
private struct HingeLight: ViewModifier {
    let hinge: HingeReader
    // Points of light travel between flat and shut. Tune by eye on a real phone.
    private static var travel: CGFloat { 12 }

    func body(content: Content) -> some View {
        let shift = (1 - hinge.openness(from: 0, to: 180)) * Self.travel
        content.transformEnvironment(\.cardTilt) { $0.width += shift }
    }
}

// The left page: one trip, described.
// In: the trip on top of the deck. Out: countdown, name, bags with their item counts, the next
// plans, and how much is home once the return check has started.
struct TripSpreadPanel: View {
    let trip: Trip

    private static var maxBags: Int { 6 }
    private static var maxPlans: Int { 4 }

    // Plans from today on, soonest first, then the ones with no day.
    private var nextPlans: [TripPlan] {
        let today = PlanDay().key(for: .now)
        let sections = trip.planSections.filter { $0.day.map { $0 >= today } ?? true }
        return Array(sections.flatMap(\.plans).prefix(Self.maxPlans))
    }

    var body: some View {
        let bags = trip.bags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let plans = nextPlans
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                label(trip.countdown())
                Text(trip.name)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                if let start = trip.startDate {
                    Text(start..<max(start, trip.endDate ?? start), format: .interval.day().month())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if bags.isEmpty, plans.isEmpty {
                Text("Nothing packed or planned yet.").foregroundStyle(.secondary)
            }

            if !bags.isEmpty {
                section("BAGS") {
                    ForEach(bags.prefix(Self.maxBags)) { bag in
                        row(Text(bag.emoji), bag.name, trailing: "\(bag.items.count)")
                    }
                    if bags.count > Self.maxBags {
                        Text("+\(bags.count - Self.maxBags) more").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            if !plans.isEmpty {
                section("NEXT") {
                    ForEach(plans) { plan in
                        let day = plan.day.flatMap { PlanDay().date(for: $0) }
                        row(Text(Image(systemName: plan.planCategory.symbol)), plan.title,
                            trailing: day?.formatted(.dateTime.weekday(.abbreviated).day()) ?? "")
                    }
                }
            }

            if trip.hasStartedReturn {
                let progress = trip.returnProgress
                section("HOME") {
                    ProgressView(value: Double(progress.confirmed), total: Double(max(1, progress.expected))) {
                        Text("\(progress.confirmed) of \(progress.expected) items").font(.subheadline)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 40)
        // Swiping the deck swaps the whole page at once.
        .id(trip.persistentModelID)
        .transition(.opacity)
        .animation(.snappy(duration: 0.3), value: trip.persistentModelID)
    }

    // Small wide capitals, the same voice as the stat labels on the card.
    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold).width(.expanded))
            .foregroundStyle(.secondary)
    }

    private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            label(title)
            rows()
        }
    }

    // mark | name ......... count or day
    private func row(_ mark: Text, _ name: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            mark.frame(width: 24)
            Text(name).lineLimit(1)
            Spacer(minLength: 8)
            Text(trailing).monospacedDigit().foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

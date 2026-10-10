import SwiftUI

// Packing data is separate from the card's moving light, so tilt updates don't need to
// sort the inventory or recount the return check.
struct TripCardChips: View {
    let trip: Trip
    let background: Color
    let border: Color

    // First ten distinct emoji, in packing order. Stop once the row is full.
    private var emojis: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in trip.items.sorted(by: { $0.addedAt < $1.addedAt }) {
            guard seen.insert(item.emoji).inserted else { continue }
            result.append(item.emoji)
            if result.count == 10 { break }
        }
        return result
    }

    var body: some View {
        let emojis = self.emojis
        if !emojis.isEmpty {
            HStack(spacing: -5) {
                ForEach(emojis, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 13))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(background))
                        .overlay(Circle().strokeBorder(border.opacity(0.6), lineWidth: 0.8))
                }
            }
            .padding(.vertical, 10)
            .accessibilityHidden(true)
        }
    }
}

struct TripCardDetails: View {
    let trip: Trip
    let text: Color
    let shadow: Color

    private var days: Int? {
        guard let start = trip.startDate, let end = trip.endDate else { return nil }
        return max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(trip.name.uppercased())
                .font(.system(size: 22, weight: .semibold).width(.expanded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(alignment: .top, spacing: 18) {
                stat("BAGS", "\(trip.bags.count)")
                stat("ITEMS", "\(trip.itemCount)")
                if let days { stat("DAYS", "\(days)") }
                Spacer(minLength: 0)
                if trip.hasStartedReturn {
                    let progress = trip.returnProgress
                    stat("HOME", "\(progress.confirmed)", of: progress.expected)
                }
            }
        }
        .foregroundStyle(text)
        .shadow(color: shadow.opacity(0.55), radius: 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func stat(_ label: String, _ value: String, of total: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold).width(.expanded))
                .foregroundStyle(text.opacity(0.75))
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value).font(.system(size: 26, weight: .bold)).monospacedDigit()
                if let total {
                    Text("/\(total)").font(.system(size: 13, weight: .medium)).foregroundStyle(text.opacity(0.7))
                }
            }
        }
    }
}

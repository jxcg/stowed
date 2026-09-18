import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var isAdding = false
    @State private var tripToDelete: Trip?

    // Upcoming trips first, soonest at the front. Undated and past trips after, newest first.
    private var orderedTrips: [Trip] {
        let today = Calendar.current.startOfDay(for: .now)
        let upcoming = trips.filter { ($0.endDate ?? $0.startDate ?? .distantPast) >= today }
            .sorted { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        let rest = trips.filter { !upcoming.contains($0) }
        return upcoming + rest
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "suitcase",
                        description: Text("Tap + to plan your first one.")
                    )
                } else {
                    stack
                }
            }
            .navigationTitle("Trips")
            .navigationDestination(for: Trip.self) { TripDetailView(trip: $0) }
            .toolbar {
                Button("Add trip", systemImage: "plus") { isAdding = true }
            }
            .sheet(isPresented: $isAdding) { TripForm() }
            // Delete cascades to everything under the trip. Confirm first.
            .confirmationDialog(
                "Delete \(tripToDelete?.name ?? "trip")?",
                isPresented: Binding(get: { tripToDelete != nil }, set: { if !$0 { tripToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let trip = tripToDelete { context.delete(trip) }
                }
            } message: {
                Text("Its bags and items go with it.")
            }
        }
    }

    // Every trip is a tall card in a vertical stack (decision 18).
    private var stack: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(orderedTrips) { card($0) }
            }
            .padding()
        }
    }

    private func card(_ trip: Trip) -> some View {
        NavigationLink(value: trip) { TripCard(trip: trip) }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) { tripToDelete = trip }
            }
    }
}

// A playing card (decision 20): thin white frame, full-bleed gradient art from the trip's hue
// with grain and a shimmer, the initial in two corners, the packed emoji as the pips.
private struct TripCard: View {
    let trip: Trip
    var tilt: CGSize = .zero

    // First 12 distinct emoji, in packing order.
    private var collage: [String] {
        var seen = Set<String>()
        return Array(trip.items.sorted { $0.addedAt < $1.addedAt }.map(\.emoji).filter { seen.insert($0).inserted }.prefix(12))
    }

    private var dates: String? {
        guard let start = trip.startDate else { return nil }
        let range = trip.endDate.map { start..<$0 }
        return range.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? start.formatted(date: .abbreviated, time: .omitted)
    }

    private func tone(_ shift: Double, _ saturation: Double, _ brightness: Double) -> Color {
        Color(hue: (trip.hue + shift).truncatingRemainder(dividingBy: 1), saturation: saturation, brightness: brightness)
    }
    private var initial: String { String(trip.name.prefix(1)).uppercased() }
    private var pip: String { collage.first ?? "✈️" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28).fill(.white)
            art.clipShape(RoundedRectangle(cornerRadius: 20)).padding(9)

            VStack(spacing: 10) {
                Text(trip.name)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .multilineTextAlignment(.center)
                if let dates {
                    Text(dates).font(.system(.subheadline, design: .serif)).opacity(0.85)
                }
                Spacer(minLength: 8)
                if collage.isEmpty {
                    Text("Nothing packed yet").font(.subheadline).opacity(0.85)
                } else {
                    Text(collage.joined(separator: "  "))
                        .font(.system(size: 34))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                Spacer(minLength: 8)
                HStack {
                    Text("\(trip.bags.count) bags · \(trip.items.count) items")
                    Spacer()
                    if trip.isReturnComplete {
                        Label("Home", systemImage: "checkmark.seal.fill").accessibilityLabel("Trip complete")
                    } else if trip.hasStartedReturn {
                        Text("Home \(trip.returnConfirmedCount) / \(trip.returnExpected.count)").monospacedDigit()
                    }
                }
                .font(.footnote)
                .opacity(0.85)
            }
            .padding(44)

            cornerMark
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            cornerMark
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 1)
        .aspectRatio(0.72, contentMode: .fit)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }

    // Gradient, a sheen that follows the tilt, a diagonal shimmer band, then grain on top.
    private var art: some View {
        ZStack {
            LinearGradient(
                colors: [tone(0, 0.75, 0.95), tone(0.08, 0.85, 0.75), tone(0.2, 0.9, 0.45)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(colors: [.white.opacity(0.4), .clear], center: .topLeading, startRadius: 0, endRadius: 380)
                .offset(tilt)
            LinearGradient(
                stops: [.init(color: .clear, location: 0.35), .init(color: .white.opacity(0.22), location: 0.5), .init(color: .clear, location: 0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .offset(x: tilt.width * 3, y: tilt.height * 3)
            grain.resizable(resizingMode: .tile).opacity(0.14).blendMode(.overlay)
        }
    }

    private var cornerMark: some View {
        VStack(spacing: 0) {
            Text(initial).font(.system(.title2, design: .serif, weight: .bold))
            Text(pip).font(.caption)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }
}

// Film grain: one tiny random-noise image, tiled across the card. Made once.
private let grain: Image = {
    let size = 96
    let pixels = (0..<size * size).map { _ in UInt8.random(in: 0...255) }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let cgImage = CGImage(
        width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
    return Image(decorative: cgImage, scale: 1)
}()

// New trip. Name required. Dates behind a toggle so an undated trip is name + Save.
private struct TripForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var hasDates = false
    @State private var startDate = Date.now
    @State private var endDate = Date.now

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Trip name", text: $name)
                Toggle("Dates", isOn: $hasDates)
                if hasDates {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("New trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(Trip(
                            name: trimmedName,
                            startDate: hasDates ? startDate : nil,
                            endDate: hasDates ? endDate : nil
                        ))
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}

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

// A playing card (decisions 20, 21): one deep colour from a curated palette, darker toward the
// edges, grain heaviest in the middle, a lattice and a double rule, a foil frame, the initial
// and suit in two corners, a monogram watermark, no emoji.
private struct TripCard: View {
    let trip: Trip
    var tilt: CGSize = .zero

    private var palette: CardPalette { trip.cardPalette }

    private var dates: String? {
        guard let start = trip.startDate else { return nil }
        let range = trip.endDate.map { start..<$0 }
        return range.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? start.formatted(date: .abbreviated, time: .omitted)
    }

    private var initial: String { String(trip.name.prefix(1)).uppercased() }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28).fill(palette.frameGradient)
            art.clipShape(RoundedRectangle(cornerRadius: 20)).padding(9)
            // Double hairline rule just inside the frame.
            RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.35), lineWidth: 1).padding(15)
            RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.18), lineWidth: 1).padding(19)

            // Monogram watermark.
            Text(initial)
                .font(.system(size: 220, weight: .bold, design: .serif))
                .opacity(0.1)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(trip.name)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("\(trip.bags.count) bags · \(trip.items.count) items")
                    .font(.system(.footnote, design: .serif))
                    .opacity(0.8)
                Spacer()
                if trip.isReturnComplete {
                    Label("Home", systemImage: "checkmark.seal.fill").font(.footnote).accessibilityLabel("Trip complete")
                } else if trip.hasStartedReturn {
                    Text("Home \(trip.returnConfirmedCount) / \(trip.returnExpected.count)").font(.footnote).monospacedDigit()
                }
                // Small-caps footer, like a foil stamp.
                Text(dates ?? "Stowed")
                    .font(.system(.caption, design: .serif).smallCaps())
                    .tracking(3)
                    .opacity(0.85)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 40)

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

    // Single hue radial, a sheen that follows the tilt, a faint shimmer, a lattice, then grain
    // masked so it is heaviest in the middle.
    private var art: some View {
        ZStack {
            RadialGradient(colors: [palette.centre, palette.edge], center: .center, startRadius: 0, endRadius: 440)
            lattice.resizable(resizingMode: .tile).opacity(0.07).blendMode(.overlay)
            RadialGradient(colors: [.white.opacity(0.16), .clear], center: .topLeading, startRadius: 0, endRadius: 360)
                .offset(tilt)
            LinearGradient(
                stops: [.init(color: .clear, location: 0.35), .init(color: .white.opacity(0.1), location: 0.5), .init(color: .clear, location: 0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .offset(x: tilt.width * 3, y: tilt.height * 3)
            grain.resizable(resizingMode: .tile)
                .opacity(0.4)
                .blendMode(.overlay)
                .mask(RadialGradient(colors: [.white, .white.opacity(0.1)], center: .center, startRadius: 30, endRadius: 380))
        }
    }

    private var cornerMark: some View {
        VStack(spacing: 2) {
            Text(initial).font(.system(.title2, design: .serif, weight: .bold))
            Text(trip.cardSuit.glyph).font(.footnote)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 26)
    }
}

// Tiny greyscale tiles, made once. `grain` is random noise; `lattice` is a diamond mesh.
private let grain = tile(size: 96) { _, _ in UInt8.random(in: 0...255) }
private let lattice = tile(size: 24) { x, y in
    let onDiagonal = abs(x - y) <= 1 || abs(x + y - 23) <= 1
    return onDiagonal ? 255 : 0
}

private func tile(size: Int, pixel: (Int, Int) -> UInt8) -> Image {
    let pixels = (0..<size * size).map { pixel($0 % size, $0 / size) }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let cgImage = CGImage(
        width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
    return Image(decorative: cgImage, scale: 1)
}

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

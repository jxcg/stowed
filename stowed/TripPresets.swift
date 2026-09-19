import Foundation

// Chips on the new-trip sheet (decision 25). Your own past trips first, then a few cities,
// so most trips are one tap. Typing still works.
enum TripPresets {
    static let cities = ["London", "Paris", "New York", "Tokyo", "Lisbon", "Barcelona", "Rome", "Berlin", "Amsterdam", "Dubai"]

    // Distinct, case-insensitive, previous names first, capped so the row stays short.
    static func suggestions(previous: [String], cities: [String] = cities, limit: Int = 8) -> [String] {
        var seen = Set<String>()
        return (previous + cities)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .prefix(limit)
            .map { $0 }
    }
}

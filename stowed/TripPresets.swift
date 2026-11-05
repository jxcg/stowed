import Foundation

// Chips on the new-trip sheet (decision 25). Your own past trips first, then a few cities,
// so most trips are one tap. Typing still works.
enum TripPresets {
    static let cities = ["London", "Paris", "New York", "Tokyo", "Lisbon", "Barcelona", "Rome", "Berlin", "Amsterdam", "Dubai"]

    // Distinct, case-insensitive, previous names first, capped so the row stays short.
    static func suggestions(previous: [String], cities: [String] = cities, limit: Int = 8) -> [String] {
        precondition(limit >= 0)
        var seen = Set<String>()
        var result: [String] = []
        for name in [previous, cities].joined() {
            guard result.count < limit else { break }
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && seen.insert(name.lowercased()).inserted { result.append(name) }
        }
        return result
    }
}

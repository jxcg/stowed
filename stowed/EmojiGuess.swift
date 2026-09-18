import Foundation

/// Picks an emoji from a name, per SPEC decision 9. Longest matching keyword wins so
/// "camera bag" beats "bag". English only for now; the user can always override.
enum EmojiGuess {
    static let bagFallback = "🧳"
    static let itemFallback = "📦"

    // ponytail: flat keyword list, extend as real names show up. A locale-aware or
    // ML-backed guess is the upgrade path if this proves too thin.
    private static let keywords: [(String, String)] = [
        ("suitcase", "🧳"), ("luggage", "🧳"), ("carry-on", "🧳"), ("carry on", "🧳"),
        ("backpack", "🎒"), ("rucksack", "🎒"), ("daypack", "🎒"),
        ("handbag", "👜"), ("purse", "👛"), ("tote", "👜"), ("clutch", "👛"),
        ("briefcase", "💼"), ("laptop bag", "💼"), ("camera bag", "📷"),
        ("duffel", "🛍️"), ("duffle", "🛍️"), ("gym bag", "🛍️"),
        ("pocket", "👖"), ("wallet", "👛"),
    ]

    static func guess(for name: String, fallback: String) -> String {
        let lowered = name.lowercased()
        let match = keywords
            .filter { lowered.contains($0.0) }
            .max { $0.0.count < $1.0.count }
        return match?.1 ?? fallback
    }
}

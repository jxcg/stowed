import SwiftUI

/// Picks an emoji from a name, per SPEC decision 9. Longest matching keyword wins so
/// "camera bag" beats "bag". English only for now; the user can always override.
enum EmojiGuess {
    static let bagFallback = "🧳"
    static let itemFallback = "📦"

    // ponytail: flat keyword list, extend as real names show up. A locale-aware or
    // ML-backed guess is the upgrade path if this proves too thin.
    private static let keywords: [(String, String)] = [
        // Bags
        ("suitcase", "🧳"), ("luggage", "🧳"), ("carry-on", "🧳"), ("carry on", "🧳"),
        ("backpack", "🎒"), ("rucksack", "🎒"), ("daypack", "🎒"),
        ("handbag", "👜"), ("purse", "👛"), ("tote", "👜"), ("clutch", "👛"),
        ("briefcase", "💼"), ("laptop bag", "💼"), ("camera bag", "📷"),
        ("duffel", "🛍️"), ("duffle", "🛍️"), ("gym bag", "🛍️"), ("pocket", "👖"),
        // Documents and money
        ("passport", "🛂"), ("ticket", "🎫"), ("boarding", "🎫"), ("wallet", "👛"),
        ("cash", "💵"), ("card", "💳"), ("key", "🔑"), ("id", "🪪"), ("licence", "🪪"), ("license", "🪪"),
        // Electronics
        ("charger", "🔌"), ("cable", "🔌"), ("adapter", "🔌"), ("plug", "🔌"),
        ("phone", "📱"), ("laptop", "💻"), ("ipad", "📱"), ("tablet", "📱"),
        ("headphone", "🎧"), ("earbud", "🎧"), ("airpod", "🎧"), ("camera", "📷"),
        ("kindle", "📖"), ("book", "📖"), ("watch", "⌚"), ("battery", "🔋"), ("power bank", "🔋"),
        // Clothes
        ("sock", "🧦"), ("shirt", "👕"), ("t-shirt", "👕"), ("tee", "👕"), ("jean", "👖"),
        ("trouser", "👖"), ("pant", "👖"), ("short", "🩳"), ("dress", "👗"), ("skirt", "👗"),
        ("jacket", "🧥"), ("coat", "🧥"), ("hoodie", "🧥"), ("jumper", "🧥"), ("sweater", "🧥"),
        ("underwear", "🩲"), ("boxer", "🩲"), ("bra", "👙"), ("swim", "🩱"), ("bikini", "👙"),
        ("shoe", "👟"), ("trainer", "👟"), ("sneaker", "👟"), ("boot", "🥾"), ("sandal", "🩴"),
        ("flip flop", "🩴"), ("hat", "🧢"), ("cap", "🧢"), ("scarf", "🧣"), ("glove", "🧤"),
        ("sunglass", "🕶️"), ("glasses", "👓"), ("belt", "👔"), ("tie", "👔"), ("pyjama", "🛌"), ("pajama", "🛌"),
        // Toiletries and health
        ("toothbrush", "🪥"), ("toothpaste", "🪥"), ("razor", "🪒"), ("shampoo", "🧴"),
        ("sunscreen", "🧴"), ("suncream", "🧴"), ("lotion", "🧴"), ("deodorant", "🧴"),
        ("soap", "🧼"), ("towel", "🛁"), ("medicine", "💊"), ("pill", "💊"), ("tablets", "💊"),
        ("plaster", "🩹"), ("bandage", "🩹"), ("first aid", "🩹"), ("makeup", "💄"), ("lipstick", "💄"),
        ("brush", "🪮"), ("comb", "🪮"), ("contact", "👁️"),
        // Misc
        ("umbrella", "☂️"), ("water bottle", "🍶"), ("bottle", "🍶"), ("snack", "🍪"),
        ("pillow", "🛏️"), ("mask", "😷"), ("pen", "🖊️"), ("notebook", "📓"), ("map", "🗺️"),
        ("lock", "🔒"), ("souvenir", "🎁"), ("gift", "🎁"), ("toy", "🧸"), ("nappy", "🍼"), ("diaper", "🍼"),
    ]

    static func guess(for name: String, fallback: String) -> String {
        let lowered = " " + name.lowercased()
        // Word-start match: "socks" hits "sock", "that" does not hit "hat".
        let match = keywords
            .filter { lowered.contains(" " + $0.0) }
            .max { $0.0.count < $1.0.count }
        return match?.1 ?? fallback
    }
}

/// A one-grapheme text field fed by the system emoji keyboard. Shared by the bag and item
/// forms so the clamp-to-one-character rule lives once.
struct EmojiField: View {
    @Binding var emoji: String
    let placeholder: String
    /// Flipped the first time the user types their own emoji, so guessing stops overriding it.
    @Binding var userChoseEmoji: Bool

    var body: some View {
        TextField(placeholder, text: $emoji)
            .frame(width: 44)
            .multilineTextAlignment(.center)
            .onChange(of: emoji) { _, new in
                let last = String(new.suffix(1))
                if new != last { emoji = last }
                if !last.isEmpty { userChoseEmoji = true }
            }
            .accessibilityLabel("Emoji")
    }
}

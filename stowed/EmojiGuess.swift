import SwiftUI

// Name in, emoji out (decision 9). Longest keyword wins, so "camera bag" beats "bag".
// English only. Wrong guess? The user taps the emoji and picks their own.
enum EmojiGuess {
    static let bagFallback = "🧳"
    static let itemFallback = "📦"

    // ponytail: flat keyword list. Add words as real names show up. Upgrade path if this
    // gets too thin: a locale-aware or ML lookup. Not before.
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
        // Leading space so we only match at word starts: "socks" hits "sock", "that" misses "hat".
        let lowered = " " + name.lowercased()
        let match = keywords
            .filter { lowered.contains(" " + $0.0) }
            .max { $0.0.count < $1.0.count }
        return match?.1 ?? fallback
    }
}

// One-character text field. The system emoji keyboard does the picking.
struct EmojiField: View {
    @Binding var emoji: String
    let placeholder: String

    var body: some View {
        TextField(placeholder, text: $emoji)
            .frame(width: 44)
            .multilineTextAlignment(.center)
            // Keep only the last character typed. Never a word in here.
            .onChange(of: emoji) { _, new in
                let last = String(new.suffix(1))
                if new != last { emoji = last }
            }
            .accessibilityLabel("Emoji")
    }
}

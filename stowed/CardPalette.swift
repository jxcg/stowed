import SwiftUI

// Ten palettes. All the card takes from one now is its accent; the rest of the card is the
// same whichever you have.
enum CardPalette: String, CaseIterable {
    case oxblood, navy, forest, plum, slate, rust, teal, charcoal, ochre, bordeaux

    // The card's accent. Its base never changes; this is the only thing that moves,
    // and there are three of them, not ten. More than that and the set stops looking like a set.
    var neonAccent: Double {
        switch self {
        case .teal, .slate, .navy: 0.52        // cyan
        case .forest, .charcoal, .plum: 0.76   // violet
        case .bordeaux, .oxblood, .rust, .ochre: 0.89  // magenta
        }
    }

}

// One suit per trip, picked at random and kept. The pip in the corners.
enum CardSuit: String, CaseIterable {
    case spade, heart, diamond, club

    var glyph: String {
        switch self {
        case .spade: "♠"
        case .heart: "♥"
        case .diamond: "♦"
        case .club: "♣"
        }
    }
}

// Three finishes for the metal print. The sheet is the same grey in all of them; what changes
// is the colour of the light landing on it, so a shelf of cards looks like one set with each
// card still its own.
enum MetalFinish: String, CaseIterable {
    case silver, titanium, champagne

    var title: String { rawValue.capitalized }

    // The two blooms that drift with the tilt.
    var warm: Color {
        switch self {
        case .silver: Color(hue: 0.93, saturation: 0.22, brightness: 0.9)
        case .titanium: Color(hue: 0.73, saturation: 0.24, brightness: 0.9)
        case .champagne: Color(hue: 0.10, saturation: 0.32, brightness: 0.94)
        }
    }
    var cool: Color {
        switch self {
        case .silver: Color(hue: 0.42, saturation: 0.2, brightness: 0.94)
        case .titanium: Color(hue: 0.55, saturation: 0.3, brightness: 0.94)
        case .champagne: Color(hue: 0.98, saturation: 0.2, brightness: 0.95)
        }
    }
    // The faint wash under them, four stops.
    var wash: [Color] {
        switch self {
        case .silver:
            [Color(hue: 0.98, saturation: 0.18, brightness: 0.98),
             Color(hue: 0.72, saturation: 0.16, brightness: 0.98),
             Color(hue: 0.50, saturation: 0.18, brightness: 0.98),
             Color(hue: 0.28, saturation: 0.16, brightness: 0.96)]
        case .titanium:
            [Color(hue: 0.74, saturation: 0.16, brightness: 0.98),
             Color(hue: 0.62, saturation: 0.18, brightness: 0.98),
             Color(hue: 0.52, saturation: 0.16, brightness: 0.98),
             Color(hue: 0.66, saturation: 0.12, brightness: 0.95)]
        case .champagne:
            [Color(hue: 0.11, saturation: 0.2, brightness: 0.99),
             Color(hue: 0.05, saturation: 0.16, brightness: 0.98),
             Color(hue: 0.96, saturation: 0.14, brightness: 0.98),
             Color(hue: 0.14, saturation: 0.14, brightness: 0.96)]
        }
    }
}

extension CardPalette {
    // Which finish a trip gets. Ten palettes onto three finishes, so it is random in practice
    // but fixed to the trip.
    var metalFinish: MetalFinish {
        switch self {
        case .oxblood, .bordeaux, .rust: .champagne
        case .navy, .slate, .charcoal: .titanium
        default: .silver
        }
    }
}

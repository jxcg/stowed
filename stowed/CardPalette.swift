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
